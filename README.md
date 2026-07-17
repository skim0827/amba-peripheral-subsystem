# amba-peripheral-subsystem

1. APB slave peripheral
2. AXI4-Lite slave
3. AXI4-Lite-to-APB bridge
4. APB decoder connecting multiple peripherals
5. Verification environment with assertions and random traffic

```
AXI4-Lite Master
       |
AXI-to-APB Bridge
       |
   APB Decoder
    /       \
GPIO       Timer
```
