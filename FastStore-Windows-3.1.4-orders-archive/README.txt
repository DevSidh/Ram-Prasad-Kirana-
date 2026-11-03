FastStore for Windows - billing and local online-order archive
Application version: 3.1.4+23

INSTALL / UPDATE
1. Close FastStore if it is currently running.
2. Extract this entire ZIP to a folder on the billing computer.
3. Run RamPrasadBilling.exe from that extracted folder.

Keep the EXE, DLL files, and data folder together. Do not run the EXE from
inside the ZIP or move it by itself.

The invoice window includes New bill. If the current bill has items, FastStore
offers to hold it before opening another bill.

On Windows, opening the online Orders screen creates and syncs order snapshots
under C:\Ramprasad\online. Current orders are grouped into Confirm order,
Order cancelled, Order to be delivered, and Order delivered. Changes are
retained in the history subfolder as JSON Lines files. The online database
remains authoritative; the local files provide a computer-side record.

Existing computer-only bills, pending-cash exports, and bill-customer files
remain under C:\Ramprasad store\bills.

Windows 10 or later, 64-bit, is required. If a Visual C++ runtime error
appears, install the Microsoft Visual C++ 2015-2022 Redistributable (x64)
from Microsoft's official site.
