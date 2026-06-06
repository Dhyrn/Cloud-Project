# Known limitations and roadmap

Honest list of what we deliberately chose to leave incomplete, plus what
would come next if this project had a third week.

The goal is to make discussion in the defense easier: every item below
has a clear *what* and a clear *how we'd fix it*.

## Things we know don't work cleanly

### 1. `ProductEventSqsPublisherTest` doesn't compile on CI

The test fails to compile with `cannot access SqsClient — class file for
SqsClient not found` even though the AWS SDK SQS dependency is on the
runtime classpath. The CI workaround is `-Dmaven.test.skip=true` in both
`ci.yml` and the `Makefile`'s `package` target.

The functional SQS flow is still validated end-to-end manually (see
`docs/deployment.md`, Verification checklist). It's the unit test for the
publisher that is broken, not the publisher itself.

**Fix candidates**, in increasing effort:
1. `mvn dependency:tree` to confirm there is no conflict between the
   Spring Cloud BOM and the AWS SDK BOM.
2. Add `mockito-inline` so Mockito can mock the sealed `SqsClient`
   interfaces from SDK v2.
3. Mark the test `@Disabled` and rewrite it with **LocalStack** in CI
   instead of mocking the SDK at all — closer to the actual integration.

### 2. Spring Boot startup takes ~50 s on t3.small

t3.micro used to take **11 minutes** because of CPU starvation during the
Hikari pool's first connection attempt. Bumping to t3.small (2 vCPU, 2 GB)
brought it to ~50 s, which is acceptable.

If we still wanted to push it lower, the options are:
- `spring.main.lazy-initialization=true` (already on for the AWS profile).
- Disable Actuator metrics, Prometheus registry, SpringDoc/Swagger in the
  AWS profile (they each pull in dozens of beans).
- Switch to **Spring Boot AOT** / **GraalVM native** image — overkill for
  this project but a real production option.

### 3. Healthchecks are timing-sensitive on cold boot

The `docker compose` healthchecks use `wget --spider`, which is a BusyBox
applet that occasionally races with Spring Boot's `/actuator/health` early
liveness probe. The first 30-60 s after a deploy can show `(unhealthy)` on
otherwise-working containers. The smoke test in `deploy.yml` and the
`Wait for api-gateway healthcheck` task in `deploy-app.yml` both poll
until the gateway returns 200, so it's transparent in production.

**Fix**: install a real `curl` in the base image (`RUN apk add --no-cache
curl`) and rewrite the healthcheck as `curl -fs
http://localhost:PORT/actuator/health || exit 1`.

## Things we deliberately scoped out

### Kafka kept only for local dev

`docker-compose.yml` (the local file) brings up Confluent Kafka +
Zookeeper. `docker-compose.aws.yml` (the production file) does NOT. The
Kafka producer/consumer beans stay loaded in the Java code via
`@EnableKafka`, but `application-aws.yml` sets
`spring.kafka.listener.auto-startup: false` and points at a placeholder
`kafka:9092` so the container starts cleanly even without a broker.

We chose this over either:
- Running **MSK** (managed Kafka) — out of scope, too expensive for a
  student project.
- Removing all Kafka code — would require rewriting `OrderEventConsumer`
  + `ProductEventConsumer` + their tests, which we judged not worth the
  defense win.

The async path in AWS is SQS only. The Kafka surface is local-dev tooling
to demonstrate the original course design.

### Single EC2 host

All four containers run on one EC2 instance, behind the same public IP. A
"more real" architecture would put them behind an ALB across multiple
AZs, with `order-service` and `product-service` on private subnets behind
the ALB. We kept one EC2 because:
- t3.small with 4 lazy-initialised JVMs is just enough.
- The defense story is the same — service separation, IAM scoping, async
  decoupling — without the extra cost or moving parts.

### `cncloud-gha-deployer` still has `PowerUserAccess`

See `docs/security.md` — this is intentional during development but the
plan is to replace with an explicit policy listing only the actions the
two workflows actually call.

### No CloudWatch dashboards or alarms (except billing)

We have the two billing alarms from the bootstrap stack, but no metric
alarms on:
- SQS queue depth
- Container restart count
- RDS connection count
- ALB 5xx rate (no ALB at all in fact)

A "monitoring" pass would add a CloudWatch dashboard plus 3-4 alarms
wired to the same SNS topic as the billing alarms.

### No structured logging shipping to CloudWatch

Containers log to stdout, which Docker captures locally. Nothing pushes
those logs off the host. To do this properly:
- Add the `awslogs` log driver to each service in `docker-compose.aws.yml`.
- Pre-create the log groups in Terraform.
- Give the EC2 instance role `logs:CreateLogStream` + `logs:PutLogEvents`.

## What would come next

If this project had another week, the priority would be (in order):

1. **Tighten `gha-deployer` role** to an explicit policy. Eliminates the
   "what could go wrong" defense question.
2. **Ship logs to CloudWatch.** Makes operating the stack vastly easier.
3. **CloudWatch alarms on SQS depth + DLQ depth.** Detects bad behaviour
   early — very high value/effort ratio.
4. **Multi-AZ RDS.** Single line of Terraform: `multi_az = true`.
   Justifiable defense win for "production-readiness".
5. **ALB + autoscaling group** for the gateway tier. Real cloud
   architecture rather than a single EC2. Adds cost but no operational
   pain.
6. **Replace SSH with SSM Session Manager.** Closes port 22 in the
   security group. Free.

None of these are *required* by the course brief. They would turn the
project from "demonstrates the requirements" into "deployable at a real
job", which is the next plateau.
