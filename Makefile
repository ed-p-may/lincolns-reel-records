.PHONY: project format lint test db-start db-test db-stop db-ci ci

SUPABASE_CLI := pnpm dlx supabase@2.109.1
SIMULATOR := platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5
SUPABASE_EXCLUDE := edge-runtime,gotrue,imgproxy,kong,logflare,mailpit,postgres-meta,postgrest,realtime,storage-api,studio,supavisor,vector

project:
	xcodegen generate

format:
	swiftformat ReelRecords ReelRecordsTests ReelRecordsUITests

lint:
	swiftformat ReelRecords ReelRecordsTests ReelRecordsUITests --lint
	swiftlint lint --strict

test: project
	xcodebuild test -project LincolnReelRecords.xcodeproj -scheme LincolnReelRecords -destination '$(SIMULATOR)' CODE_SIGNING_ALLOWED=NO

db-start:
	$(SUPABASE_CLI) start -x $(SUPABASE_EXCLUDE)

db-test:
	$(SUPABASE_CLI) test db --local supabase/tests/database

db-stop:
	$(SUPABASE_CLI) stop

db-ci:
	@set -eu; \
	started=0; \
	if ! $(SUPABASE_CLI) status >/dev/null 2>&1; then \
		$(SUPABASE_CLI) start -x $(SUPABASE_EXCLUDE); \
		started=1; \
	fi; \
	cleanup() { if [ "$$started" -eq 1 ]; then $(SUPABASE_CLI) stop; fi; }; \
	trap cleanup EXIT INT TERM; \
	$(SUPABASE_CLI) db reset --local; \
	$(SUPABASE_CLI) test db --local supabase/tests/database

ci: lint test db-ci
