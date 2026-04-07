# Monitor de energia residencial

Aplicação web para acompanhar **geração solar** (integração Solarman), **consumo** (Tuya / medidor Wi‑Fi), **saldo**, **custos** e **previsões**, com **JWT**, **WebSocket** para leituras ao vivo e deploy via **Docker Compose**.

## Stack

| Camada    | Tecnologia                          |
|----------|--------------------------------------|
| Backend  | Python 3.12, FastAPI, SQLAlchemy 2   |
| Frontend | React 18, Vite, Recharts             |
| Banco    | PostgreSQL 16                        |
| Cache    | Redis (opcional, serviço no Compose) |
| Auth     | JWT (Bearer)                         |

## Início rápido (Docker)

Na raiz do projeto:

```bash
docker compose up --build
```

- **Interface:** [http://localhost](http://localhost) (nginx → frontend + proxy `/api` → backend)  
- **API direta:** [http://localhost:8000/docs](http://localhost:8000/docs)  
- **Usuário padrão:** `admin` / `admin123` (definidos por `DEFAULT_ADMIN_USER` / `DEFAULT_ADMIN_PASSWORD` no Compose — **altere em produção**)

Defina `SECRET_KEY` no ambiente ou no arquivo `.env` na raiz (Compose lê variáveis do host).

### Redis (opcional)

```bash
docker compose --profile redis up -d redis
```

No backend, `USE_REDIS=true` e `REDIS_URL` habilitam uso futuro de cache/pub-sub (estrutura preparada; o fluxo principal não depende de Redis).

## Desenvolvimento local

### Um comando: `npm run rodar`

Na **raiz** do repositório (primeira vez: instale dependências Python no `backend` e do front no `frontend`, como abaixo):

```bash
npm install
npm run rodar
```

Sobe **API** (FastAPI, porta **8080**, SQLite local via `USE_LOCAL_SQLITE=true`) e **interface** (Vite, **http://localhost:5173**). Para parar: `Ctrl+C` (encerra os dois).

Equivalente: `npm run dev`.

Se usar só PostgreSQL, remova o `USE_LOCAL_SQLITE` do script em `package.json` ou suba o Postgres e ajuste o `.env` do backend.

### Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate   # Windows
pip install -r requirements.txt
copy .env.example .env     # ajuste URLs, SECRET_KEY e Solarman (não commite .env)
```

Suba o PostgreSQL (ou use o do Compose apenas para o banco):

```bash
docker compose up -d postgres
```

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

O Vite faz proxy de `/api` para a URL em `frontend/.env.development` (`VITE_DEV_API_URL`, padrão comum **8080** quando usa `npm run rodar`).

## Variáveis de ambiente (backend)

| Variável | Descrição |
|----------|-----------|
| `DATABASE_URL` | URL async (`postgresql+asyncpg://...`) |
| `SYNC_DATABASE_URL` | URL sync (`postgresql://...`) para utilitários |
| `SECRET_KEY` | Chave JWT (obrigatória em produção) |
| `SOLARMAN_USE_MOCK` | `true` = coletor usa simulação; `false` + credenciais = API real |
| `SOLARMAN_USERNAME`, `SOLARMAN_PASSWORD`, `SOLARMAN_PLANT_ID` | Login Solarman + ID da planta/usina (apenas `.env`) |
| `SOLARMAN_BASE_URL` | Padrão `https://api.solarmanpv.com` |
| `SOLARMAN_LANGUAGE` | Ex.: `en` |
| `SOLARMAN_APP_ID`, `SOLARMAN_APP_SECRET` | Obrigatórios em muitas contas (solicitar à Solarman) |
| `SOLARMAN_API_URL` | Legado: URL alternativa do coletor |
| `TUYA_USE_MOCK` | `true` = simulação |
| `TUYA_ACCESS_ID`, `TUYA_ACCESS_SECRET`, `TUYA_ENDPOINT`, `TUYA_DEVICE_ID` | Tuya Open API |
| `DEFAULT_ADMIN_USER` / `DEFAULT_ADMIN_PASSWORD` | Seed se não houver usuários |
| `OPENWEATHER_API_KEY` | Chave [OpenWeatherMap](https://openweathermap.org/api) (opcional; sem chave a previsão usa só histórico local) |
| `WEATHER_LATITUDE`, `WEATHER_LONGITUDE` | Coordenadas da residência para clima (padrão: São Paulo) |

### Previsão com clima e dashboard premium

1. **Dependências Python:** `pip install -r backend/requirements.txt` em um **venv** limpo evita conflito de versões entre `numpy` e `scikit-learn`.
2. **Clima:** defina `OPENWEATHER_API_KEY` no `backend/.env`. A API usa `weather` + `forecast` (2.5) com **cache de 30 minutos** em memória. Se a chamada falhar, o sistema usa **fallback neutro** e continua respondendo.
3. **Endpoints (JWT):**
   - `GET /api/weather/forecast` — temperatura, nuvens, chuva provável, amanhã resumido.
   - `GET /api/forecast/advanced` — previsão híbrida (médias 7d, dia da semana, ajuste climático, regressão Ridge quando há amostras suficientes), insights em texto e **gravação** em `forecast_history`.
4. **Testar:** faça login (`POST /api/auth/login`), copie o `access_token` e no Swagger (`/docs`) use **Authorize** ou:  
   `curl -H "Authorization: Bearer <token>" http://127.0.0.1:8080/api/forecast/advanced`

## API principal (todas protegidas por JWT, exceto login/registro)

| Método | Caminho | Descrição |
|--------|---------|-----------|
| POST | `/api/auth/login` | Token JWT |
| POST | `/api/auth/register` | Novo usuário |
| GET | `/api/generation?hours=` | Histórico geração |
| GET | `/api/consumption?hours=` | Histórico consumo |
| GET | `/api/balance?hours=` | Saldo energético |
| GET | `/api/cost` | Tarifa atual |
| PUT | `/api/cost` | Atualizar `price_per_kwh` |
| GET | `/api/cost/estimate?period=day\|month` | Custo estimado |
| GET | `/api/forecast` | Média 7 dias e projeção mensal |
| GET | `/api/forecast/advanced` | Previsão com clima, projeção mensal, insights (persiste histórico) |
| GET | `/api/weather/forecast` | Clima atual e amanhã (cache 30 min) |
| GET | `/api/live` | Snapshot atual (W) |
| GET | `/api/alerts` | Alertas (consumo > geração, picos) |
| GET | `/api/reports/summary?period=day\|month` | Relatório agregado |
| GET | `/api/reports/grid-import-series` | Série importação rede |
| GET | `/api/solarman/live` | Geração Solarman ao vivo (cache 5 min; JWT) |
| WS | `/api/ws/live?token=<JWT>` | Eventos JSON `type: live` |
| GET | `/api/consumption/patterns` | Picos de consumo (7 dias) |
| POST | `/api/simulation/economy` | Simulador de economia (JSON) |
| GET | `/api/solar/efficiency` | Eficiência solar (`auto=true` opcional) |

### API Solarman (`/api/solarman/live`)

1. Copie `backend/.env.example` para `backend/.env` e preencha **sem** commitar o arquivo.
2. Defina `SOLARMAN_USERNAME`, `SOLARMAN_PASSWORD` e `SOLARMAN_PLANT_ID` (ex.: id da usina no portal).
3. Para dados reais no coletor do dashboard, use `SOLARMAN_USE_MOCK=false`.
4. O backend obtém token em `POST /account/v1.0/token` e chama `device/v1.0/currentData` (tenta senha clara, SHA256 e `SOLARMAN_APP_ID` / `SOLARMAN_APP_SECRET` quando existirem).
5. **Cache em memória:** leituras repetidas em até **5 minutos** reutilizam o mesmo resultado; se a API falhar, devolve o **último valor válido** com `status: "stale"`.
6. Resposta JSON: `power_w`, `energy_today_kwh`, `energy_month_kwh`, `status` (`online` ou `stale`).

**Segurança:** não coloque credenciais no código nem em logs; não versione `.env`. Se um segredo foi exposto, **troque a senha** no portal Solarman.

Documentação interativa: `/docs` e esquema OpenAPI em `/openapi.json` (adequado para **app mobile** ou clientes gerados).

## Coleta de dados

- **Solarman:** tarefa em background a cada **5 minutos** (`app/services/collector.py` + `solarman_service.py`). Com `SOLARMAN_USE_MOCK=false` e credenciais no `.env`, usa a **API oficial** (mesmo cache de 5 min que o endpoint `GET /api/solarman/live`).
- **Tuya:** amostragem a cada **~3 s**; em produção configure credenciais e DPs conforme o modelo do dispositivo (`tuya_service.py`). A assinatura da API Tuya em produção costuma exigir fluxo de **access token** — o arquivo deixa um stub para evolução.

## Banco de dados

Tabelas criadas automaticamente no startup:

- `users` — autenticação  
- `energy_generation` — `timestamp`, `power_w`, `energy_kwh`  
- `energy_consumption` — `timestamp`, `voltage`, `current`, `power_w`, `energy_kwh`  
- `energy_balance` — `generated_kwh`, `consumed_kwh`, `balance_kwh`  
- `cost_config` — `price_per_kwh`  
- `forecast_history` — snapshots de `GET /api/forecast/advanced` (`forecast_date`, kWh, custo, resumo climático, `confidence_score`)

## Grafana (futuro)

- Use o plugin **Infinity** ou **JSON API** apontando para os endpoints REST com header `Authorization: Bearer <token>`.  
- Alternativa: expor métricas Prometheus no backend (não incluído neste repositório) e usar o data source Prometheus no Grafana.

## Deploy em VPS (Oracle, AWS, etc.)

1. Instale Docker e Docker Compose.  
2. Clone o repositório e configure `SECRET_KEY` e senhas fortes.  
3. `docker compose up -d --build`.  
4. Coloque TLS (Caddy, Traefik ou nginx + Let’s Encrypt) na frente da porta 80.  
5. Desative ou proteja `POST /api/auth/register` em produção (firewall ou remoção da rota).

## Estrutura do código

```
backend/app/
  main.py              # FastAPI, CORS, WebSocket, lifespan
  models.py            # ORM
  routers/             # auth, energy, reports, solarman, weather, forecast_advanced, intelligence
  services/
    solarman_service.py
    tuya_service.py
    energy_calculator.py
    weather_service.py   # OpenWeather + cache + fallback
    forecast_service.py # previsão híbrida + sklearn (lazy)
    collector.py       # loops de coleta
frontend/src/
  components/          # EnergyFlowPanel, ForecastCard, Insights, KPI premium, etc.
  services/            # forecastService.ts, weatherService.ts
  pages/               # Dashboard, Login, Reports
  hooks/useLiveWebSocket.ts
```

## Licença

Uso interno / projeto próprio — ajuste conforme necessário.
