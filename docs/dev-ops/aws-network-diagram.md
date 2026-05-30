# Схема сети AWS (dev окружение)

Регион: `eu-north-1`

```
Интернет
    │
    │ HTTP :80
    ▼
┌─────────────────────────────────────────────────────────────────┐
│  ALB  dmc-1-t1-notebook-dev-alb                                 │
│  Security Group: alb-sg (inbound 80 от 0.0.0.0/0)              │
│                                                                  │
│  Listener rules:                                                 │
│    /api/v1/*  ──►  api-tg (port 8000)                           │
│    /*         ──►  ui-tg  (port 80)   [default]                 │
└──────────────────┬──────────────────────────────────────────────┘
                   │
    ┌──────────────┴──────────────┐
    │  VPC  10.0.0.0/16           │
    │                             │
    │  Public Subnets             │
    │  ┌─────────────┐  ┌────────────────┐
    │  │ public-a    │  │ public-b       │
    │  │ 10.0.1.0/24 │  │ 10.0.2.0/24   │
    │  │ eu-north-1a │  │ eu-north-1b   │
    │  │             │  │               │
    │  │ NAT Gateway │  │               │
    │  └──────┬──────┘  └───────────────┘
    │         │ (исходящий трафик из приватных подсетей)
    │  Private Subnets            │
    │  ┌─────────────┐  ┌────────────────┐
    │  │ private-a   │  │ private-b      │
    │  │ 10.0.10.0/24│  │ 10.0.11.0/24  │
    │  │ eu-north-1a │  │ eu-north-1b   │
    │  │             │  │               │
    │  │ ECS Task    │  │               │
    │  │  api :8000  │  │               │
    │  │  ui  :80    │  │               │
    │  │             │  │               │
    │  │ RDS         │  │               │
    │  │ :5432       │  │               │
    │  └─────────────┘  └───────────────┘
    └─────────────────────────────┘
```

## Security Groups

```
alb-sg
  inbound:  TCP 80  от 0.0.0.0/0
  outbound: все

ecs-sg
  inbound:  TCP 8000  от alb-sg   (API контейнер)
            TCP 80    от alb-sg   (UI контейнер)
  outbound: все (нужен для pull образов из GHCR через NAT)

rds-sg
  inbound:  TCP 5432  от ecs-sg
  outbound: все
```

## Routing

```
Публичные подсети:  0.0.0.0/0  →  Internet Gateway
Приватные подсети:  0.0.0.0/0  →  NAT Gateway (в public-a)
```

> NAT Gateway позволяет ECS-задачам в приватных подсетях скачивать
> Docker-образы из GHCR не имея публичного IP.
