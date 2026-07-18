import asyncio
import logging
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import StreamingResponse

router = APIRouter(prefix="/relay", tags=["relay"])

active_transfers: dict[str, asyncio.Queue] = {}
logger = logging.getLogger(__name__)

def get_or_create_queue(transfer_id: str) -> asyncio.Queue:
    if transfer_id not in active_transfers:
        active_transfers[transfer_id] = asyncio.Queue(maxsize=10)
    return active_transfers[transfer_id]

@router.post("/upload/{transfer_id}/{chunk_index}")
async def upload_chunk(transfer_id: str, chunk_index: int, request: Request):
    queue = get_or_create_queue(transfer_id)
    body = await request.body()
    
    try:
        await asyncio.wait_for(queue.put((chunk_index, body)), timeout=30.0)
    except asyncio.TimeoutError:
        raise HTTPException(status_code=408, detail="Receiver disconnected or too slow")
        
    return {"status": "ok"}

@router.post("/upload/{transfer_id}/complete")
async def complete_upload(transfer_id: str):
    if transfer_id in active_transfers:
        queue = active_transfers[transfer_id]
        try:
            await asyncio.wait_for(queue.put(None), timeout=10.0)
        except asyncio.TimeoutError:
            pass
    return {"status": "ok"}

@router.delete("/upload/{transfer_id}")
async def cancel_upload(transfer_id: str):
    if transfer_id in active_transfers:
        queue = active_transfers.pop(transfer_id, None)
        if queue:
            try:
                queue.put_nowait(None)
            except asyncio.QueueFull:
                pass
    return {"status": "ok"}

@router.get("/download/{transfer_id}")
async def download_transfer(transfer_id: str):
    queue = get_or_create_queue(transfer_id)
    
    async def chunk_generator():
        try:
            while True:
                # Wait for chunks. If no chunk for 60s, assume sender dropped
                item = await asyncio.wait_for(queue.get(), timeout=60.0)
                if item is None:
                    active_transfers.pop(transfer_id, None)
                    break
                
                chunk_idx, data = item
                idx_bytes = chunk_idx.to_bytes(4, byteorder='big')
                len_bytes = len(data).to_bytes(4, byteorder='big')
                yield idx_bytes + len_bytes + data
                queue.task_done()
        except asyncio.TimeoutError:
            active_transfers.pop(transfer_id, None)
            raise HTTPException(status_code=408, detail="Sender disconnected")
        except asyncio.CancelledError:
            active_transfers.pop(transfer_id, None)
            try:
                queue.put_nowait(None)
            except asyncio.QueueFull:
                pass
            raise

    return StreamingResponse(chunk_generator(), media_type="application/octet-stream")
