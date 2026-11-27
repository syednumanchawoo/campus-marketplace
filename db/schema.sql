CREATE TABLE users (
    user_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_name VARCHAR(50) NOT NULL UNIQUE,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    phone VARCHAR(15) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'STUDENT'
        CHECK (role IN ('STUDENT', 'ADMIN')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    CONSTRAINT chk_iust_email CHECK (
        email = LOWER(email)
        AND email ~ '^[a-z0-9._%+-]+@(iust\.ac\.in|islamicuniversity\.edu\.in)$'
    )
);

CREATE TABLE email_otps (
    otp_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    otp_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_otp_expiry CHECK (expires_at > created_at)
);

CREATE TABLE categories (
    category_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL,
    parent_category_id INT REFERENCES categories(category_id) ON DELETE RESTRICT,
    CONSTRAINT uq_parent_category_name
        UNIQUE NULLS NOT DISTINCT (parent_category_id, category_name),
    CONSTRAINT chk_no_self_parent CHECK (parent_category_id <> category_id)
);

CREATE TABLE listings (
    listing_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    category_id INT NOT NULL REFERENCES categories(category_id) ON DELETE RESTRICT,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    item_condition VARCHAR(20)
        CHECK (item_condition IN ('NEW', 'GOOD', 'FAIR')),
    status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE'
        CHECK (status IN ('AVAILABLE', 'RESERVED', 'SOLD', 'REMOVED', 'REMOVED')),
    listing_type VARCHAR(20) NOT NULL DEFAULT 'SALE'
        CHECK (listing_type IN ('SALE', 'RENTAL', 'BARTER', 'SERVICE')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE images (
    image_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    listing_id INT NOT NULL REFERENCES listings(listing_id) ON DELETE CASCADE,
    image_url VARCHAR(500) NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE
);
-- At most one primary thumbnail image per listing
CREATE UNIQUE INDEX uq_one_primary_image
    ON images (listing_id)
    WHERE is_primary = TRUE;

CREATE TABLE offers (
    offer_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    listing_id INT NOT NULL REFERENCES listings(listing_id) ON DELETE CASCADE,
    buyer_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    offered_price DECIMAL(10,2) NOT NULL
        CHECK (offered_price >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'WITHDRAWN', 'CANCELLED')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    order_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    offer_id INT NOT NULL UNIQUE REFERENCES offers(offer_id) ON DELETE RESTRICT,
    payment_method VARCHAR(20) NOT NULL
        CHECK (payment_method IN ('NONE', 'CASH', 'UPI', 'BANK_TRANSFER')),
    meetup_location VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'IN PROCESS'
        CHECK (status IN ('IN_PROCESS', 'CANCELLED', 'COMPLETED')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
        CHECK (completed_at IS NULL OR status = 'COMPLETED')
);
-- At most one active accepted offer per listing
CREATE UNIQUE INDEX uq_one_accepted_offer
    ON offers (listing_id)
    WHERE status = 'ACCEPTED';

CREATE TABLE conversations (
    conversation_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    listing_id INT NOT NULL REFERENCES listings(listing_id) ON DELETE RESTRICT,
    buyer_id INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_listing_buyer UNIQUE (listing_id, buyer_id)
);

CREATE TABLE messages (
    message_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    conversation_id INT NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    sender_id INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    content TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE reviews (
    review_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reviewer_id INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT,
    rating SMALLINT NOT NULL
        CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_order_reviewer UNIQUE (order_id, reviewer_id)
);
