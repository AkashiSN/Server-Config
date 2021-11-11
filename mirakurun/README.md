## Channel Scan

- GR
```bash
curl -X PUT "http://localhost:40772/api/config/channels/scan?refresh=true&type=GR"
```

- BS
```bash
curl -X PUT "http://localhost:40772/api/config/channels/scan?refresh=true&type=BS&setDisabledOnAdd=false"
```