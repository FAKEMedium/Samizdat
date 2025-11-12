-- Based in Sweden (BIS) Database Schema
-- Tracks hosting compliance for Swedish organizations
-- Uses existing languages from public.languages (joined by code: 'en', 'sv')

-- Create BIS schema
CREATE SCHEMA IF NOT EXISTS bis;

-- Main domains table (only domain name, no localized content)
CREATE TABLE bis.domains (
  id SERIAL PRIMARY KEY,
  domain VARCHAR(255) UNIQUE NOT NULL,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_domains_active ON bis.domains(active);
CREATE INDEX idx_domains_domain ON bis.domains(domain);

-- Localized domain descriptions
CREATE TABLE bis.domain_descriptions (
  id SERIAL PRIMARY KEY,
  domain_id INT NOT NULL REFERENCES bis.domains(id) ON DELETE CASCADE,
  languageid INT NOT NULL REFERENCES public.languages(languageid) ON DELETE CASCADE,
  title VARCHAR(500),
  description TEXT,
  CONSTRAINT domain_descriptions_unique UNIQUE (domain_id, languageid)
);

CREATE INDEX idx_domain_descriptions_domain ON bis.domain_descriptions(domain_id);
CREATE INDEX idx_domain_descriptions_lang ON bis.domain_descriptions(languageid);

-- Tags for categorization (only metadata, no names)
CREATE TABLE bis.tags (
  id SERIAL PRIMARY KEY,
  color VARCHAR(7) DEFAULT '#0066cc',  -- Hex color for UI
  priority INT DEFAULT 0,  -- Higher priority tags shown first
  created_at TIMESTAMP DEFAULT NOW()
);

-- Localized tag names and descriptions
CREATE TABLE bis.tag_names (
  id SERIAL PRIMARY KEY,
  tag_id INT NOT NULL REFERENCES bis.tags(id) ON DELETE CASCADE,
  languageid INT NOT NULL REFERENCES public.languages(languageid) ON DELETE CASCADE,
  key VARCHAR(100) NOT NULL,  -- Internal key like 'government', 'healthcare'
  display_name VARCHAR(200) NOT NULL,
  description TEXT,
  CONSTRAINT tag_names_unique UNIQUE (tag_id, languageid)
);

CREATE INDEX idx_tag_names_tag ON bis.tag_names(tag_id);
CREATE INDEX idx_tag_names_lang ON bis.tag_names(languageid);
CREATE INDEX idx_tag_names_key ON bis.tag_names(key);

-- Domain to tag mapping
CREATE TABLE bis.domain_tags (
  domain_id INT REFERENCES bis.domains(id) ON DELETE CASCADE,
  tag_id INT REFERENCES bis.tags(id) ON DELETE CASCADE,
  PRIMARY KEY (domain_id, tag_id)
);

CREATE INDEX idx_domain_tags_domain ON bis.domain_tags(domain_id);
CREATE INDEX idx_domain_tags_tag ON bis.domain_tags(tag_id);

-- Check runs (each cron execution)
CREATE TABLE bis.runs (
  id SERIAL PRIMARY KEY,
  started_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP,
  domains_checked INT DEFAULT 0,
  status VARCHAR(50) DEFAULT 'running',  -- running, completed, failed
  notes TEXT
);

CREATE INDEX idx_runs_started ON bis.runs(started_at DESC);

-- DNS record checks
CREATE TABLE bis.checks (
  id SERIAL PRIMARY KEY,
  run_id INT REFERENCES bis.runs(id) ON DELETE CASCADE,
  domain_id INT REFERENCES bis.domains(id) ON DELETE CASCADE,
  record_type VARCHAR(10) NOT NULL,  -- A, AAAA, MX, NS
  record_value VARCHAR(500),
  ip_address INET,
  country_code CHAR(2),  -- SE, US, etc.
  asn INT,  -- Autonomous System Number
  as_name VARCHAR(500),  -- AS organization name
  hosting_provider VARCHAR(500),  -- Detected provider (AWS, Azure, Bahnhof, etc.)
  is_compliant BOOLEAN DEFAULT FALSE,  -- TRUE if Swedish
  checked_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_checks_run ON bis.checks(run_id);
CREATE INDEX idx_checks_domain ON bis.checks(domain_id);
CREATE INDEX idx_checks_type ON bis.checks(record_type);
CREATE INDEX idx_checks_compliant ON bis.checks(is_compliant);
CREATE INDEX idx_checks_provider ON bis.checks(hosting_provider);

-- Domain scores per run
CREATE TABLE bis.scores (
  id SERIAL PRIMARY KEY,
  run_id INT REFERENCES bis.runs(id) ON DELETE CASCADE,
  domain_id INT REFERENCES bis.domains(id) ON DELETE CASCADE,
  score INT CHECK (score >= 0 AND score <= 100),  -- 0-100%
  total_checks INT DEFAULT 0,
  compliant_checks INT DEFAULT 0,
  a_compliant BOOLEAN DEFAULT FALSE,
  aaaa_compliant BOOLEAN DEFAULT NULL,  -- NULL if no AAAA records
  mx_compliant BOOLEAN DEFAULT NULL,  -- NULL if no MX records
  ns_compliant BOOLEAN DEFAULT FALSE,
  has_bis_badge BOOLEAN DEFAULT FALSE,  -- TRUE if 100% compliant
  primary_provider VARCHAR(500),  -- Main hosting provider detected
  notes TEXT,
  calculated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(run_id, domain_id)
);

CREATE INDEX idx_scores_run ON bis.scores(run_id);
CREATE INDEX idx_scores_domain ON bis.scores(domain_id);
CREATE INDEX idx_scores_score ON bis.scores(score DESC);
CREATE INDEX idx_scores_badge ON bis.scores(has_bis_badge);

-- Provider patterns for identification (only metadata, no names)
CREATE TABLE bis.providers (
  id SERIAL PRIMARY KEY,
  country_code CHAR(2) NOT NULL,
  is_swedish BOOLEAN DEFAULT FALSE,
  cloud_act_applies BOOLEAN DEFAULT FALSE,  -- US providers under Cloud Act
  asn_list INT[],  -- Array of ASNs
  as_name_patterns TEXT[],  -- Array of AS name patterns for matching
  ip_ranges CIDR[],  -- Array of IP ranges
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_providers_swedish ON bis.providers(is_swedish);

-- Localized provider names and notes
CREATE TABLE bis.provider_names (
  id SERIAL PRIMARY KEY,
  provider_id INT NOT NULL REFERENCES bis.providers(id) ON DELETE CASCADE,
  languageid INT NOT NULL REFERENCES public.languages(languageid) ON DELETE CASCADE,
  key VARCHAR(100) NOT NULL,  -- Internal key like 'aws', 'bahnhof'
  name VARCHAR(200) NOT NULL,  -- Display name
  notes TEXT,
  CONSTRAINT provider_names_unique UNIQUE (provider_id, languageid)
);

CREATE INDEX idx_provider_names_provider ON bis.provider_names(provider_id);
CREATE INDEX idx_provider_names_lang ON bis.provider_names(languageid);
CREATE INDEX idx_provider_names_key ON bis.provider_names(key);

-- Historical summary for trend charts
CREATE TABLE bis.statistics (
  id SERIAL PRIMARY KEY,
  run_id INT REFERENCES bis.runs(id) ON DELETE CASCADE UNIQUE,
  total_domains INT DEFAULT 0,
  compliant_domains INT DEFAULT 0,
  compliance_rate DECIMAL(5,2),  -- 0.00-100.00%
  a_compliance_rate DECIMAL(5,2),
  mx_compliance_rate DECIMAL(5,2),
  ns_compliance_rate DECIMAL(5,2),
  avg_score DECIMAL(5,2),
  calculated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_statistics_run ON bis.statistics(run_id);

-- Insert default tags
INSERT INTO bis.tags (id, color, priority) VALUES
  (1, '#004B87', 100),  -- government
  (2, '#D32F2F', 95),   -- healthcare
  (3, '#005C99', 90),   -- municipality
  (4, '#0066AA', 85),   -- region
  (5, '#1976D2', 80),   -- education
  (6, '#388E3C', 75),   -- legal
  (7, '#7B1FA2', 70),   -- media
  (8, '#616161', 50);   -- private

-- Insert English tag names (using language code 'en')
INSERT INTO bis.tag_names (tag_id, languageid, key, display_name, description)
SELECT 1, languageid, 'government', 'Government', 'Government agencies and departments' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 2, languageid, 'healthcare', 'Healthcare', 'Healthcare providers and hospitals' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 3, languageid, 'municipality', 'Municipality', 'Municipal organizations' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 4, languageid, 'region', 'Region', 'Regional authorities' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 5, languageid, 'education', 'Education', 'Schools and universities' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 6, languageid, 'legal', 'Legal', 'Law firms and legal services' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 7, languageid, 'media', 'Media', 'News organizations and media outlets' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 8, languageid, 'private', 'Private', 'Private companies' FROM public.languages WHERE code = 'en';

-- Insert Swedish tag names (using language code 'sv')
INSERT INTO bis.tag_names (tag_id, languageid, key, display_name, description)
SELECT 1, languageid, 'government', 'Myndigheter', 'Statliga myndigheter och departement' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 2, languageid, 'healthcare', 'Sjukvård', 'Vårdgivare och sjukhus' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 3, languageid, 'municipality', 'Kommuner', 'Kommunala organisationer' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 4, languageid, 'region', 'Regioner', 'Regionala myndigheter' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 5, languageid, 'education', 'Utbildning', 'Skolor och universitet' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 6, languageid, 'legal', 'Juridik', 'Advokatbyråer och juridiska tjänster' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 7, languageid, 'media', 'Media', 'Nyhetsorganisationer och medieföretag' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 8, languageid, 'private', 'Privat', 'Privata företag' FROM public.languages WHERE code = 'sv';

-- Insert common providers
INSERT INTO bis.providers (id, country_code, is_swedish, cloud_act_applies, as_name_patterns) VALUES
  (1, 'SE', TRUE, FALSE, ARRAY['BAHNHOF', 'BAHNHOF-NET']),
  (2, 'SE', TRUE, FALSE, ARRAY['SAFESPRING']),
  (3, 'SE', TRUE, FALSE, ARRAY['GLESYS']),
  (4, 'SE', TRUE, FALSE, ARRAY['LOOPIA']),
  (5, 'SE', TRUE, FALSE, ARRAY['BINERO']),
  (6, 'US', FALSE, TRUE, ARRAY['AMAZON-AES', 'AMAZON-02', 'AMAZON']),
  (7, 'US', FALSE, TRUE, ARRAY['MICROSOFT-CORP-MSN-AS-BLOCK']),
  (8, 'US', FALSE, TRUE, ARRAY['GOOGLE', 'GOOGLE-CLOUD-PLATFORM']),
  (9, 'US', FALSE, TRUE, ARRAY['CLOUDFLARE']);

-- Insert English provider names
INSERT INTO bis.provider_names (provider_id, languageid, key, name, notes)
SELECT 1, languageid, 'bahnhof', 'Bahnhof', 'Swedish ISP and hosting provider' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 2, languageid, 'safespring', 'Safespring', 'Swedish cloud provider' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 3, languageid, 'glesys', 'Glesys', 'Swedish hosting provider' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 4, languageid, 'loopia', 'Loopia', 'Swedish domain and hosting provider' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 5, languageid, 'binero', 'Binero', 'Swedish hosting provider' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 6, languageid, 'aws', 'AWS', 'Amazon Web Services' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 7, languageid, 'azure', 'Microsoft Azure', 'Microsoft Azure cloud' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 8, languageid, 'gcp', 'Google Cloud', 'Google Cloud Platform' FROM public.languages WHERE code = 'en'
UNION ALL SELECT 9, languageid, 'cloudflare', 'Cloudflare', 'Cloudflare CDN/proxy' FROM public.languages WHERE code = 'en';

-- Insert Swedish provider names
INSERT INTO bis.provider_names (provider_id, languageid, key, name, notes)
SELECT 1, languageid, 'bahnhof', 'Bahnhof', 'Svenskt ISP och webbhotell' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 2, languageid, 'safespring', 'Safespring', 'Svensk molntjänstleverantör' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 3, languageid, 'glesys', 'Glesys', 'Svenskt webbhotell' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 4, languageid, 'loopia', 'Loopia', 'Svensk domän- och webbhotellsleverantör' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 5, languageid, 'binero', 'Binero', 'Svenskt webbhotell' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 6, languageid, 'aws', 'AWS', 'Amazon Web Services' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 7, languageid, 'azure', 'Microsoft Azure', 'Microsoft Azure molntjänst' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 8, languageid, 'gcp', 'Google Cloud', 'Google Cloud Platform' FROM public.languages WHERE code = 'sv'
UNION ALL SELECT 9, languageid, 'cloudflare', 'Cloudflare', 'Cloudflare CDN/proxy' FROM public.languages WHERE code = 'sv';

-- View for latest scores
CREATE VIEW bis.latest_scores AS
SELECT
  s.*,
  d.domain,
  r.started_at as check_date
FROM bis.scores s
JOIN bis.domains d ON s.domain_id = d.id
JOIN bis.runs r ON s.run_id = r.id
WHERE r.id = (SELECT MAX(id) FROM bis.runs WHERE status = 'completed')
ORDER BY s.score DESC;

-- View for sector statistics (English)
CREATE VIEW bis.sector_stats AS
SELECT
  tn.key as sector,
  tn.display_name,
  COUNT(DISTINCT d.id) as total_domains,
  COUNT(DISTINCT CASE WHEN s.has_bis_badge THEN d.id END) as compliant_domains,
  ROUND(AVG(s.score), 2) as avg_score,
  ROUND(100.0 * COUNT(DISTINCT CASE WHEN s.has_bis_badge THEN d.id END) / NULLIF(COUNT(DISTINCT d.id), 0), 2) as compliance_rate
FROM bis.tags t
JOIN bis.tag_names tn ON t.id = tn.tag_id
  AND tn.languageid = (SELECT languageid FROM public.languages WHERE code = 'en' LIMIT 1)
JOIN bis.domain_tags dt ON t.id = dt.tag_id
JOIN bis.domains d ON dt.domain_id = d.id
JOIN bis.scores s ON d.id = s.domain_id
WHERE s.run_id = (SELECT MAX(id) FROM bis.runs WHERE status = 'completed')
  AND d.active = TRUE
GROUP BY tn.key, tn.display_name, t.priority
ORDER BY t.priority DESC;

-- View for provider statistics (English)
CREATE VIEW bis.provider_stats AS
SELECT
  c.hosting_provider,
  pn.name as provider_name,
  bp.country_code,
  bp.is_swedish,
  bp.cloud_act_applies,
  COUNT(DISTINCT c.domain_id) as domain_count,
  COUNT(*) as total_records
FROM bis.checks c
LEFT JOIN bis.provider_names pn ON c.hosting_provider = pn.key
  AND pn.languageid = (SELECT languageid FROM public.languages WHERE code = 'en' LIMIT 1)
LEFT JOIN bis.providers bp ON pn.provider_id = bp.id
WHERE c.run_id = (SELECT MAX(id) FROM bis.runs WHERE status = 'completed')
GROUP BY c.hosting_provider, pn.name, bp.country_code, bp.is_swedish, bp.cloud_act_applies
ORDER BY domain_count DESC;
