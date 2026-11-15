# Garage S3 backup

Garage provides a single-node S3 endpoint for the `coworker-backup` bucket at
`https://s3.feddema.dev`. Object data lives on the dedicated HDD attached to
`hortek-0`; Garage metadata and snapshots live on Ceph.

This deployment has no object-data redundancy. Loss of the HDD or `hortek-0`
loses this copy, so the coworker must retain another copy.

## Rollout

1. Confirm `hortek-0` reports the intended 3 TB disk as WWID
  `naa.5000c5007cf099c8` before applying Talos config.
2. Render and apply the Talos config with `talos/update-config.sh -n hortek-0`.
3. Confirm `u-garage-data` is ready and mounted at `/var/mnt/garage-data`.
4. Set `products.storage.garage.deploy` to `true` in `chart/values.yaml`.
5. Sync Garage and verify the pod, PVCs, route, quota, and metrics.

## Client configuration

- Endpoint: `https://s3.feddema.dev`
- Region: `garage`
- Bucket: `coworker-backup`
- Addressing style: path

Retrieve the generated credentials for one-time secure delivery:

```sh
kubectl get secret garage-s3-credentials -n garage \
  -o jsonpath='{.data.accessKeyId}' | base64 -d; echo
kubectl get secret garage-s3-credentials -n garage \
  -o jsonpath='{.data.secretAccessKey}' | base64 -d; echo
```

This client key has read/write access to `coworker-backup`; the internal Garage
bootstrap key is not for client use.

For rclone, set `provider = Other`, `region = garage`, the endpoint above, and
`force_path_style = true`.

## Operations

- Change `s3.quota` to adjust the bucket limit; the sync hook reapplies it.
- Rotate client credentials by creating a replacement Garage key, granting it
  read/write access to `coworker-backup`, and updating `garage-s3-credentials`
  in a planned maintenance window. Never delete `garage-credentials` while the
  existing Garage metadata remains.
- Before replacing the HDD, copy all objects to another S3 target. A retained PV
  protects against Kubernetes deletion, not disk failure.
- Upgrades must preserve Garage metadata, data, RPC secret, and S3 credentials.
- Decommission by disabling the Argo CD application first. Delete the retained
  local PV or wipe the Talos user volume only after separately confirming that
  the data is no longer needed.
