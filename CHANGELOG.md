# [1.1.0](https://gitlab.miquido.com/miquido/terraform/proxmox-docker-host/compare/v1.0.1...v1.1.0) (2026-10-12)


### Features

* image_file_name and roles_anywhere_key_gid, a complete example, docker-host 2.1.0 ([80b185f](https://gitlab.miquido.com/miquido/terraform/proxmox-docker-host/commit/80b185fdcd82a1f7212cf2fd454601038fc3cb12))

## [1.0.1](https://gitlab.miquido.com/miquido/terraform/proxmox-docker-host/compare/v1.0.0...v1.0.1) (2026-10-08)


### Bug Fixes

* make DNS-01 via IAM Roles Anywhere actually work (AWS_CONFIG_FILE and AWS_REGION) ([658006a](https://gitlab.miquido.com/miquido/terraform/proxmox-docker-host/commit/658006a3a663eedfb95338737c36f67877d3934a))

# 1.0.0 (2026-10-07)


### Bug Fixes

* review follow-ups — NAS restore/backup race, registry auth, narrower chown, pinned versions ([15359b3](https://gitlab.miquido.com/miquido/terraform/proxmox-docker-host/commit/15359b39ab6bf59b2ee8a90a7d704f169d960046))
* use docker-host v2.0.1 (fresh boots no longer abort in write_files) ([6781c12](https://gitlab.miquido.com/miquido/terraform/proxmox-docker-host/commit/6781c12a01d581a77873029ded855d100c2843bf))


### Features

* initial release — Proxmox docker host built on terraform-docker-host v2 ([7a2823c](https://gitlab.miquido.com/miquido/terraform/proxmox-docker-host/commit/7a2823cee4a31b75e65b43c654966fdcfaa71cae))
