# check_hpe_windows_team

Check status of network team devices on Hewlett Packard Devices using SNMP.

This works by scanning the snmp table of ".1.3.6.1.4.1.232.18.2.2.1" under CPQNIC.mib for devices. Reads whole table but monitors
just de entries that "look real", skipping loopback and some weird result I've got from some devices. 
The idea is to make monitoring easy, avoiding the need to identify the device either by name or index.
