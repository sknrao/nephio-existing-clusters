Let me search for specific information about the structure of these packages and where NAD references appear.Perfect! Now I have enough information. Let me create a comprehensive guide for you.Perfect! I've created a comprehensive guide that shows you exactly where to make changes to reference your NADs in the Nephio Free5GC and OAI packages.

## Key Takeaways

**The main files you need to modify are the `interface-*.yaml` files** in each blueprint package:

### For Free5GC (on my-core):
- `pkg-example-amf-bp/interface-n2.yaml` 
- `pkg-example-smf-bp/interface-n4.yaml`
- `pkg-example-upf-bp/interface-n3.yaml`, `interface-n4.yaml`, `interface-n6.yaml`

### For OAI RAN (on my-ran):
- `pkg-example-cucp-bp/interface-n2.yaml`, `interface-f1c.yaml`, `interface-e1.yaml`
- `pkg-example-cuup-bp/interface-e1.yaml`, `interface-f1u.yaml`, `interface-n3.yaml`
- `pkg-example-du-bp/interface-f1c.yaml`, `interface-f1u.yaml`

## The Interface Resource

These Interface resources are the "glue" between high-level network intent and actual NADs. They contain:
- `nephio.org/network-name` annotation (network type: n2, n3, etc.)
- `networkInstance.name` (maps to your topology)
- `cniType` (macvlan in your case)
- `attachmentType` (set to "none" since you don't need VLANs)

## Two Approaches

1. **Fork & Modify** (recommended for full control) - Fork the catalog repo, update Interface files to reference your network names
2. **NAD Name Mapping** - Use labels on your NADs to match what Nephio expects

The guide includes a complete network interface mapping table showing which NADs should be used for each network function and interface type.

Would you like me to create example modified Interface files for a specific network function (like AMF or CU-CP) to show exactly what the changes look like?