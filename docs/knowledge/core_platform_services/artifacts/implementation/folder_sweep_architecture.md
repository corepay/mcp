# Cloud Storage & Folder Sweep Architecture

The Folder Sweep system automates document processing by monitoring S3/MinIO buckets and importing new files into Workspaces.

## 1. Folder Architecture
The system uses a 3-stage pipeline:
1.  **Input (Process) Folder**: The "Hot Folder" scanned by the back-end `FolderSweepWorker`.
2.  **Output Folder**: Destination for successfully processed files (optional).
3.  **Error Folder**: Quarantine for files that failed processing.

## 2. Configuration Schema
Configuration is stored in `workspace.settings.storage`.

```json
{
  "storage": {
    "input": {
      "source": "storage",
      "bucket_id": "uuid"
    },
    "scheduling": {
      "enabled": true,
      "interval_minutes": 60
    }
  }
}
```

## 3. Implementation: FolderSweepWorker
The worker performs the following on each interval:
1.  List objects in the source bucket using `ExAws.S3.list_objects_v2`.
2.  Deduplicate based on file hash (ETag).
3.  Trigger document processing.
4.  Update `workspace.last_sweep_at`.

## 4. Resolution Pattern
Workers must resolve the physical bucket `name` from the `bucket_id` (UUID) stored in settings to ensure robustness against bucket renames or slug changes.
