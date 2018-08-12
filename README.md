Restart aria2c when download speed falls below set threshold.

Usage: 

    ./aria2c-reset MIN STRIKES ARGS
    
— Where:

    * `MIN`:
    
        Minimum speed threshold in KiB.

    * `STRIKES`:
    
        How many seconds to tolerate speed lower than threshold before restarting.

    * `ARGS`:

        Arguments to `aria2c` invocation.


