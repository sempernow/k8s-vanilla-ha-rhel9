# Elastic/Kibana


1. Browse to __Kibana__ ("elastic" name/logo)
    - http://192.168.11.101:30001/app/home
        - `NODE_IP:KIBANA_SVC_NODEPORT`
1. Select __Management > Stack Management > Kibana > Index Patterns__
    - Create Index Pattern: `logstach-*`
1. Select __Analytics > Discover__
    - See logs
    - http://192.168.11.101:30001/app/discover


## `efk-chatgpt`

### http://192.168.11.101:30001/app/discover

KCL : Kibana Query Language

Select `log` and `kubernetes.container_name` from "__Available fields__" using the "+" button, which moves them to  "__Selected fields__"
```ini
kubernetes.container_name: "my-api" AND log: "*404*"
```

Not seeing any of the useful fields, only those above.

ChatGPT says logs are unstructured because Fluent-bit parser needs work,
so saved original/running version (`04-fluentbit.v0.0.0.yaml`),
and modified and deployed newer version (`04-fluentbit.yaml`).

Deleted pods to ingest the new configmap, yet the mods had no change whatsoever.

ChatGPT says:

__Most likely causes__:

1. The log field is not named log after merging.
This breaks your merge_parser logic — Fluent Bit may be trying to parse the wrong key.
1. The embedded JSON is malformed or truncated.
We saw that earlier log lines were cut off at the end — this could cause parsing to fail silently.
1. The parser isn’t being invoked at all.
Because Fluent Bit's merge_parser only runs when Merge_Log succeeds — if the merged field is missing or the wrong key is specified, nothing happens.