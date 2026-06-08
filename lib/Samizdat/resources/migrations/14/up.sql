-- Migration 14: Create example schema and table for Example plugin demonstration

-- Create schema for example plugin
CREATE SCHEMA IF NOT EXISTS example;

-- Create example table in the example schema
CREATE TABLE IF NOT EXISTS example.example (
    id              SERIAL PRIMARY KEY,
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    content         TEXT,
    status          VARCHAR(50) DEFAULT 'draft',
    category        VARCHAR(100),
    tags            TEXT[],

    -- Checkbox fields
    active          BOOLEAN DEFAULT false,
    featured        BOOLEAN DEFAULT false,
    published       BOOLEAN DEFAULT false,

    -- Metadata fields
    creator         INTEGER,
    updater         INTEGER,
    created         TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated         TIMESTAMP WITH TIME ZONE DEFAULT NOW()

    -- Foreign key constraints (optional - depends on your user table)
    -- CONSTRAINT fk_creator FOREIGN KEY (creator) REFERENCES account.user(userid) ON DELETE SET NULL,
    -- CONSTRAINT fk_updater FOREIGN KEY (updater) REFERENCES account.user(userid) ON DELETE SET NULL
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_example_status ON example.example(status);
CREATE INDEX IF NOT EXISTS idx_example_category ON example.example(category);
CREATE INDEX IF NOT EXISTS idx_example_active ON example.example(active);
CREATE INDEX IF NOT EXISTS idx_example_published ON example.example(published);
CREATE INDEX IF NOT EXISTS idx_example_created ON example.example(created DESC);
CREATE INDEX IF NOT EXISTS idx_example_tags ON example.example USING GIN(tags);

-- Create full text search index for content searching
CREATE INDEX IF NOT EXISTS idx_example_fulltext ON example.example
    USING GIN(to_tsvector('english', coalesce(title, '') || ' ' || coalesce(description, '') || ' ' || coalesce(content, '')));

-- Add comment to schema and table
COMMENT ON SCHEMA example IS 'Example plugin schema demonstrating Samizdat plugin structure';
COMMENT ON TABLE example.example IS 'Example table demonstrating typical Samizdat plugin structure';
COMMENT ON COLUMN example.example.id IS 'Primary key';
COMMENT ON COLUMN example.example.title IS 'Example title';
COMMENT ON COLUMN example.example.description IS 'Short description or summary';
COMMENT ON COLUMN example.example.content IS 'Full content, may contain HTML';
COMMENT ON COLUMN example.example.status IS 'Status: draft, active, inactive';
COMMENT ON COLUMN example.example.category IS 'Category for grouping';
COMMENT ON COLUMN example.example.tags IS 'Array of tags for filtering';
COMMENT ON COLUMN example.example.active IS 'Whether the example is active';
COMMENT ON COLUMN example.example.featured IS 'Whether to feature this example';
COMMENT ON COLUMN example.example.published IS 'Whether this is published';
COMMENT ON COLUMN example.example.creator IS 'User ID who created this';
COMMENT ON COLUMN example.example.updater IS 'User ID who last updated this';
COMMENT ON COLUMN example.example.created IS 'Creation timestamp';
COMMENT ON COLUMN example.example.updated IS 'Last update timestamp';