# Electric Load Generation

Code to load test an Electric instance by simulating any number of concurrently connected clients.

## Running Locally

This repo has a docker compose setup that allows for running a full end-to-end
test of the electric stack on your local machine.

1.  `make clients=1000` - builds and launches a self-contained electric
    instance, fronted by a Varnish proxy with 1000 clients connected over HTTP

    Options:

    - `clients=N` set the number of clients to launch and connect. Default `1000`.

          make clients=2000

2.  `make txns duration=60 tps=8` - generates 8 database transactions per second for 60 seconds

    Options:

    - `duration=S` run for `S` seconds, default `300`

          make txns duration=60

    - `tps=N` insert `N` rows per second, default `1`

          make txns tps=4

As the clients receive the db transactions, you will see messages from the client coordinator.

- `[start: [id: ID, ...` - the row with id `ID` has been received by a client

- `[complete: [id: ID, ...` - the row with id `ID` has been received by all
  clients. The `duration` value here is the time in milliseconds between the
  receipt of the first `start` message and the last.

### Statistics

If you connect to the stack's pg database:

    psql "postgresql://postgres:password@127.0.0.1:5555/electric"

You can see some views that show the latency statistics, i.e. the time between the transaction write and receipt by the electric clients:

To see overall statistics for latencies for all sampled transactions:

     select * from latency_overview;

And for the latencies of the first receipt:

     select * from latency_overview1;

All latencies are in milliseconds.

See [postgres/init.sql](./postgres/init.sql) for the full set of views and db schema.

## Deploying Using Fly

You can also generate client connections to a real Electric instance (running
behind a CDN) using Fly to bring up a geo-distributed set of client load
instances.

The `client_load` directory has a `fly.toml` file suitable for deploying any
number of instances.

Assuming that your (CDN fronted) electric instance is running at
`https://cdn.electric.my-app.com` and is connected to some database at
`postgresql://usr:password@pg.electric.my-app.com`:

- Make sure your Postgres instance has the right schema as defined in
  [postgres/init.sql](./postgres/init.sql)

- Edit the [fly config](./client_load/fly.toml):

  Set:

  - `ELECTRIC_URL` to e.g. `https://cdn.electric.my-app.com`
  - `DATABASE_URL` to e.g. `postgresql://user:password@pg.electric.my-app.com`
  - `CLIENT_COUNT` this defaults to `5000` but, depending on your workload, as
    in the number of transactions per second you're generating, can be pushed to
    `10000` or `15000`.

- Deploy it to your fly account:

      cd client_load
      fly deploy --ha=false

  And scale it to the number of active connections you want:

      cd client_load
      fly scale count 10 --region ams,lhr,mad,fra,cdg,arn,otp

  Fly recommends spreading your machines across various regions. The above
  example uses Fly's European data centres. Every machine will create
  `CLIENT_COUNT` connections.

- Generate some database transactions:

      DATABASE_URL="postgresql://usr:password@pg.electric.my-app.com" make txns

- Monitor your clients:

      cd client_load
      fly logs

  As for the local setup, latency statistics will be written to your Postgres instance.

- Once you're done, scale down your client machines:

      cd client_load
      fly scale count 0
