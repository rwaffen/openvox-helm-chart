# Rootless initialization

Set `global.rootless: true` together with the restricted security-context profile.
Leave `global.runAsNonRoot: false`; that older mode relies on a root pre-install job.
Initialization retains directory and configuration setup but skips ownership changes.
Persistent server data is seeded from the image without replacing existing files.

Use OpenVox Server, OpenVoxDB and r10k images that support an arbitrary UID in group 0.
Their entrypoints must run without switching users, and application directories must be group-writable.
The chart does not repair existing PVC ownership; prepare old volumes before switching profiles.
Keep the root filesystem writable unless all image-specific write paths have been mounted separately.
Validate the exact image tags, CA initialization, certificate imports and restarts on the target cluster.
