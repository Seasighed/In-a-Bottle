create extension if not exists pgcrypto;

create table if not exists public.survey_responses (
  response_id uuid primary key default gen_random_uuid(),
  survey_id text not null,
  template_version integer not null,
  schema_hash text not null,
  payload_hash text not null,
  client_install_id text not null default '',
  submitted_at timestamptz not null,
  quality_metadata jsonb not null default '{}'::jsonb,
  scrub_identifying_info boolean not null default false,
  volunteered_profile jsonb,
  raw_payload jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists survey_responses_survey_identity_idx
  on public.survey_responses (survey_id, template_version, schema_hash);

create unique index if not exists survey_responses_identity_payload_hash_uidx
  on public.survey_responses (survey_id, template_version, schema_hash, payload_hash);

create index if not exists survey_responses_submitted_at_idx
  on public.survey_responses (submitted_at desc);

create index if not exists survey_responses_install_created_at_idx
  on public.survey_responses (client_install_id, created_at desc);

alter table public.survey_responses enable row level security;

comment on table public.survey_responses is
  'Private raw survey response intake for In a Bottle. Public sharing should use reviewed aggregate exports, not direct row access.';

create table if not exists public.survey_upload_rejections (
  rejection_id uuid primary key default gen_random_uuid(),
  survey_id text,
  template_version integer,
  schema_hash text,
  payload_hash text,
  client_install_id text not null default '',
  reason text not null,
  message text not null,
  endpoint_version text not null default 'survey-upload-v1',
  origin text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists survey_upload_rejections_reason_created_at_idx
  on public.survey_upload_rejections (reason, created_at desc);

create index if not exists survey_upload_rejections_survey_created_at_idx
  on public.survey_upload_rejections (survey_id, template_version, schema_hash, created_at desc);

alter table public.survey_upload_rejections enable row level security;

comment on table public.survey_upload_rejections is
  'Private survey upload rejection telemetry for moderation, rollout diagnostics, and anti-abuse checks.';
