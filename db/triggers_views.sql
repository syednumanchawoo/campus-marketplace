-- USERS -> Trim full_name, user_name, email and Lower(user_name, email)
CREATE OR REPLACE FUNCTION trim_lower_user_credentials()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.full_name := TRIM(NEW.full_name);
    NEW.user_name := LOWER(TRIM(NEW.user_name));
    NEW.email := LOWER(TRIM(NEW.email));
    IF NEW.full_name IS NULL OR NEW.full_name = '' THEN
        RAISE EXCEPTION 'full_name cannot be blank';
    END IF;

    IF NEW.user_name IS NULL OR NEW.user_name = '' THEN
        RAISE EXCEPTION 'user_name cannot be blank';
    END IF;

    IF NEW.email IS NULL OR NEW.email = '' THEN
        RAISE EXCEPTION 'email cannot be blank';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_trim_lower_user_credentials
BEFORE INSERT OR UPDATE OF full_name, user_name, email ON users
FOR EACH ROW
EXECUTE FUNCTION trim_lower_user_credentials();


-- Block unverified or deactivated users from creating listings, offers, or conversations
CREATE OR REPLACE FUNCTION check_verified_active_user()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT;
    v_is_verified BOOLEAN;
    v_is_active BOOLEAN;
BEGIN
    IF TG_TABLE_NAME = 'listing' THEN
        v_user_id := NEW.seller_id;
    ELSIF TG_TABLE_NAME IN ('offers', 'conversations') THEN
        v_user_id := NEW.buyer_id;
    ELSE
        RAISE EXCEPTION 'check_verified_active_user() is not configured for table: %', TG_TABLE_NAME;
    END IF;

    SELECT is_verified, is_active
    INTO v_is_verified, v_is_active
    FROM users
    WHERE user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User (user_id: %) does not exist.', v_user_id;
    END IF;

    IF NOT v_is_verified THEN
        RAISE EXCEPTION 'User (user_id: %) must verify their university email before inserting into %.', v_user_id, TG_TABLE_NAME;
    END IF;

    IF NOT v_is_active THEN
        RAISE EXCEPTION 'User (user_id: %) account is deactivated.', v_user_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_listings_check_user
BEFORE INSERT ON listings
FOR EACH ROW
EXECUTE FUNCTION check_verified_active_user();

CREATE OR REPLACE TRIGGER trg_offers_check_user
BEFORE INSERT ON offers
FOR EACH ROW
EXECUTE FUNCTION check_verified_active_user();

CREATE OR REPLACE TRIGGER trg_conversations_check_user
BEFORE INSERT ON conversations
FOR EACH ROW
EXECUTE FUNCTION check_verified_active_user();


-- Prevent Self Offer
CREATE OR REPLACE FUNCTION fn_prevent_self_offer()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_seller_id INT;
BEGIN
    SELECT seller_id INTO v_seller_id
    FROM listings
    WHERE listing_id = NEW.listing_id;

    IF v_seller_id = NEW.buyer_id THEN
        RAISE EXCEPTION 'Sellers cannot make offers on their own listings (listing_id: %)', NEW.listing_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_no_self_offer
    BEFORE INSERT ON offers
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_self_offer();
