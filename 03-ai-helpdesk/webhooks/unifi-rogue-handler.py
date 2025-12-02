from fastapi import FastAPI, Request, Header
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi.responses import JSONResponse

app = FastAPI()
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


@app.post("/unifi/rogue-dhcp")
@limiter.limit("10/minute")
async def rogue_dhcp(request: Request, x_unifi_vlan: int = Header(...)):
    # VLAN 90 override: allow 20/minute
    if x_unifi_vlan == 90:
        limiter._storage.reset(request)
        limiter._storage.incr(request, "20/minute")
    # Simulate osTicket ticket creation
    data = await request.json()
    # ... (Leo's exact ticket logic here)
    return JSONResponse({"status": "ticket created", "data": data})
