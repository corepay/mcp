--
-- PostgreSQL database dump
--


-- Dumped from database version 17.7 (Debian 17.7-3.pgdg13+1)
-- Dumped by pg_dump version 17.7 (Debian 17.7-3.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: address_types; Type: TABLE DATA; Schema: platform; Owner: base_mcp_dev
--

INSERT INTO platform.address_types (value, label, description, is_active, sort_order, created_at) VALUES ('home', 'Home Address', 'Personal home address', true, 1, '2025-11-26 05:21:44');
INSERT INTO platform.address_types (value, label, description, is_active, sort_order, created_at) VALUES ('business', 'Business Address', 'Business/office address', true, 2, '2025-11-26 05:21:44');
INSERT INTO platform.address_types (value, label, description, is_active, sort_order, created_at) VALUES ('shipping', 'Shipping Address', 'Shipping/delivery address', true, 3, '2025-11-26 05:21:44');
INSERT INTO platform.address_types (value, label, description, is_active, sort_order, created_at) VALUES ('billing', 'Billing Address', 'Billing address for invoices', true, 4, '2025-11-26 05:21:44');
INSERT INTO platform.address_types (value, label, description, is_active, sort_order, created_at) VALUES ('legal', 'Legal Address', 'Legal/registered address', true, 5, '2025-11-26 05:21:44');
INSERT INTO platform.address_types (value, label, description, is_active, sort_order, created_at) VALUES ('warehouse', 'Warehouse', 'Warehouse/fulfillment center', true, 6, '2025-11-26 05:21:44');
INSERT INTO platform.address_types (value, label, description, is_active, sort_order, created_at) VALUES ('pickup', 'Pickup Location', 'Customer pickup location', true, 7, '2025-11-26 05:21:44');


--
-- Data for Name: document_types; Type: TABLE DATA; Schema: platform; Owner: base_mcp_dev
--

INSERT INTO platform.document_types (value, label, description, is_sensitive, requires_encryption, retention_years, allowed_mime_types, is_active, sort_order, created_at) VALUES ('kyc_id', 'KYC ID Document', 'Government-issued ID', true, true, 7, '{image/jpeg,image/png,application/pdf}', true, 1, '2025-11-26 05:21:44');
INSERT INTO platform.document_types (value, label, description, is_sensitive, requires_encryption, retention_years, allowed_mime_types, is_active, sort_order, created_at) VALUES ('kyc_address_proof', 'KYC Address Proof', 'Proof of address', true, true, 7, '{image/jpeg,image/png,application/pdf}', true, 2, '2025-11-26 05:21:44');
INSERT INTO platform.document_types (value, label, description, is_sensitive, requires_encryption, retention_years, allowed_mime_types, is_active, sort_order, created_at) VALUES ('contract', 'Contract', 'Legal contract', true, true, 10, '{application/pdf}', true, 3, '2025-11-26 05:21:44');
INSERT INTO platform.document_types (value, label, description, is_sensitive, requires_encryption, retention_years, allowed_mime_types, is_active, sort_order, created_at) VALUES ('invoice', 'Invoice', 'Invoice document', false, false, 7, '{application/pdf}', true, 4, '2025-11-26 05:21:44');
INSERT INTO platform.document_types (value, label, description, is_sensitive, requires_encryption, retention_years, allowed_mime_types, is_active, sort_order, created_at) VALUES ('receipt', 'Receipt', 'Payment receipt', false, false, 7, '{application/pdf}', true, 5, '2025-11-26 05:21:44');
INSERT INTO platform.document_types (value, label, description, is_sensitive, requires_encryption, retention_years, allowed_mime_types, is_active, sort_order, created_at) VALUES ('tax_form', 'Tax Form', 'Tax document', true, true, 7, '{application/pdf}', true, 6, '2025-11-26 05:21:44');
INSERT INTO platform.document_types (value, label, description, is_sensitive, requires_encryption, retention_years, allowed_mime_types, is_active, sort_order, created_at) VALUES ('legal', 'Legal Document', 'Legal filing', true, true, NULL, '{application/pdf}', true, 7, '2025-11-26 05:21:44');
INSERT INTO platform.document_types (value, label, description, is_sensitive, requires_encryption, retention_years, allowed_mime_types, is_active, sort_order, created_at) VALUES ('bank_statement', 'Bank Statement', 'Bank account statement', true, true, 7, '{application/pdf}', true, 8, '2025-11-26 05:21:44');
INSERT INTO platform.document_types (value, label, description, is_sensitive, requires_encryption, retention_years, allowed_mime_types, is_active, sort_order, created_at) VALUES ('business_license', 'Business License', 'Business registration', true, true, 10, '{image/jpeg,image/png,application/pdf}', true, 9, '2025-11-26 05:21:44');


--
-- Data for Name: email_types; Type: TABLE DATA; Schema: platform; Owner: base_mcp_dev
--

INSERT INTO platform.email_types (value, label, is_active, sort_order, created_at) VALUES ('personal', 'Personal', true, 1, '2025-11-26 05:21:44');
INSERT INTO platform.email_types (value, label, is_active, sort_order, created_at) VALUES ('work', 'Work', true, 2, '2025-11-26 05:21:44');
INSERT INTO platform.email_types (value, label, is_active, sort_order, created_at) VALUES ('support', 'Support', true, 3, '2025-11-26 05:21:44');
INSERT INTO platform.email_types (value, label, is_active, sort_order, created_at) VALUES ('billing', 'Billing', true, 4, '2025-11-26 05:21:44');
INSERT INTO platform.email_types (value, label, is_active, sort_order, created_at) VALUES ('noreply', 'No Reply', true, 5, '2025-11-26 05:21:44');
INSERT INTO platform.email_types (value, label, is_active, sort_order, created_at) VALUES ('sales', 'Sales', true, 6, '2025-11-26 05:21:44');
INSERT INTO platform.email_types (value, label, is_active, sort_order, created_at) VALUES ('marketing', 'Marketing', true, 7, '2025-11-26 05:21:44');


--
-- Data for Name: entity_types; Type: TABLE DATA; Schema: platform; Owner: base_mcp_dev
--

INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('user', 'User', 'Global platform user', 'core', true, 1, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('user_profile', 'User Profile', 'Entity-scoped user profile', 'core', true, 2, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('tenant', 'Tenant', 'Top-level tenant entity', 'core', true, 3, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('developer', 'Developer', 'External API developer', 'core', true, 4, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('reseller', 'Reseller', 'Partner reseller', 'core', true, 5, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('merchant', 'Merchant', 'Merchant account', 'core', true, 6, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('store', 'Store', 'Store entity', 'core', true, 7, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('customer', 'Customer', 'End customer', 'core', true, 8, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('vendor', 'Vendor', 'Vendor/supplier', 'core', true, 9, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('product', 'Product', 'Product entity', 'commerce', true, 10, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('product_variant', 'Product Variant', 'Product SKU variant', 'commerce', true, 11, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('category', 'Category', 'Product category', 'commerce', true, 12, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('collection', 'Collection', 'Product collection', 'commerce', true, 13, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('order', 'Order', 'Customer order', 'commerce', true, 14, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('order_item', 'Order Item', 'Line item in order', 'commerce', true, 15, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('cart', 'Shopping Cart', 'Customer cart', 'commerce', true, 16, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('cart_item', 'Cart Item', 'Item in cart', 'commerce', true, 17, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('transaction', 'Transaction', 'Payment transaction', 'payments', true, 20, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('payment_method', 'Payment Method', 'Saved payment method', 'payments', true, 21, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('refund', 'Refund', 'Payment refund', 'payments', true, 22, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('chargeback', 'Chargeback', 'Payment chargeback', 'payments', true, 23, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('payout', 'Payout', 'Merchant payout', 'payments', true, 24, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('mid', 'MID', 'Merchant ID account', 'payments', true, 25, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('shipment', 'Shipment', 'Order shipment', 'shipping', true, 30, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('shipment_item', 'Shipment Item', 'Item in shipment', 'shipping', true, 31, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('tracking_event', 'Tracking Event', 'Shipment tracking update', 'shipping', true, 32, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('page', 'Page', 'CMS page', 'content', true, 40, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('blog_post', 'Blog Post', 'Blog article', 'content', true, 41, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('media', 'Media', 'Media asset', 'content', true, 42, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('campaign', 'Campaign', 'Marketing campaign', 'marketing', true, 50, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('discount', 'Discount', 'Discount rule', 'marketing', true, 51, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('coupon', 'Coupon', 'Coupon code', 'marketing', true, 52, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('loyalty_program', 'Loyalty Program', 'Customer loyalty program', 'marketing', true, 53, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('ticket', 'Support Ticket', 'Customer support ticket', 'support', true, 60, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('message', 'Message', 'Support message', 'support', true, 61, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.entity_types (value, label, description, category, is_active, sort_order, metadata, inserted_at, updated_at) VALUES ('kb_article', 'Knowledge Base Article', 'Help article', 'support', true, 62, '{}', '2025-11-26 05:21:44', '2025-11-26 05:21:44');


--
-- Data for Name: image_types; Type: TABLE DATA; Schema: platform; Owner: base_mcp_dev
--

INSERT INTO platform.image_types (value, label, max_file_size, allowed_mime_types, is_active, sort_order, created_at) VALUES ('avatar', 'Avatar', 5242880, '{image/jpeg,image/png,image/webp}', true, 1, '2025-11-26 05:21:44');
INSERT INTO platform.image_types (value, label, max_file_size, allowed_mime_types, is_active, sort_order, created_at) VALUES ('logo', 'Logo', 2097152, '{image/png,image/svg+xml}', true, 2, '2025-11-26 05:21:44');
INSERT INTO platform.image_types (value, label, max_file_size, allowed_mime_types, is_active, sort_order, created_at) VALUES ('banner', 'Banner', 10485760, '{image/jpeg,image/png,image/webp}', true, 3, '2025-11-26 05:21:44');
INSERT INTO platform.image_types (value, label, max_file_size, allowed_mime_types, is_active, sort_order, created_at) VALUES ('product', 'Product Image', 5242880, '{image/jpeg,image/png,image/webp}', true, 4, '2025-11-26 05:21:44');
INSERT INTO platform.image_types (value, label, max_file_size, allowed_mime_types, is_active, sort_order, created_at) VALUES ('gallery', 'Gallery Image', 10485760, '{image/jpeg,image/png,image/webp}', true, 5, '2025-11-26 05:21:44');
INSERT INTO platform.image_types (value, label, max_file_size, allowed_mime_types, is_active, sort_order, created_at) VALUES ('document_scan', 'Document Scan', 20971520, '{image/jpeg,image/png,application/pdf}', true, 6, '2025-11-26 05:21:44');
INSERT INTO platform.image_types (value, label, max_file_size, allowed_mime_types, is_active, sort_order, created_at) VALUES ('thumbnail', 'Thumbnail', 1048576, '{image/jpeg,image/png,image/webp}', true, 7, '2025-11-26 05:21:44');


--
-- Data for Name: phone_types; Type: TABLE DATA; Schema: platform; Owner: base_mcp_dev
--

INSERT INTO platform.phone_types (value, label, is_active, supports_sms, sort_order, created_at) VALUES ('mobile', 'Mobile', true, true, 1, '2025-11-26 05:21:44');
INSERT INTO platform.phone_types (value, label, is_active, supports_sms, sort_order, created_at) VALUES ('home', 'Home', true, false, 2, '2025-11-26 05:21:44');
INSERT INTO platform.phone_types (value, label, is_active, supports_sms, sort_order, created_at) VALUES ('work', 'Work', true, false, 3, '2025-11-26 05:21:44');
INSERT INTO platform.phone_types (value, label, is_active, supports_sms, sort_order, created_at) VALUES ('fax', 'Fax', true, false, 4, '2025-11-26 05:21:44');
INSERT INTO platform.phone_types (value, label, is_active, supports_sms, sort_order, created_at) VALUES ('support', 'Support', true, true, 5, '2025-11-26 05:21:44');
INSERT INTO platform.phone_types (value, label, is_active, supports_sms, sort_order, created_at) VALUES ('toll_free', 'Toll Free', true, false, 6, '2025-11-26 05:21:44');


--
-- Data for Name: plan_types; Type: TABLE DATA; Schema: platform; Owner: base_mcp_dev
--

INSERT INTO platform.plan_types (value, label, description, features, pricing, limits, is_active, sort_order, inserted_at, updated_at) VALUES ('starter', 'Starter', 'For small businesses getting started', '{}', '{"monthly": 0}', '{"max_users": 2, "max_api_calls": 1000}', true, 1, '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.plan_types (value, label, description, features, pricing, limits, is_active, sort_order, inserted_at, updated_at) VALUES ('professional', 'Professional', 'For growing businesses', '{}', '{"annual": 490, "monthly": 49}', '{"max_users": 10, "max_api_calls": 10000}', true, 2, '2025-11-26 05:21:44', '2025-11-26 05:21:44');
INSERT INTO platform.plan_types (value, label, description, features, pricing, limits, is_active, sort_order, inserted_at, updated_at) VALUES ('enterprise', 'Enterprise', 'For large organizations', '{}', '{"annual": 1490, "monthly": 149}', '{"max_users": -1, "max_api_calls": -1}', true, 3, '2025-11-26 05:21:44', '2025-11-26 05:21:44');


--
-- Data for Name: social_platforms; Type: TABLE DATA; Schema: platform; Owner: base_mcp_dev
--

INSERT INTO platform.social_platforms (value, label, icon, url_pattern, is_active, sort_order, created_at) VALUES ('twitter', 'Twitter/X', 'twitter', 'https://twitter.com/{username}', true, 1, '2025-11-26 05:21:44');
INSERT INTO platform.social_platforms (value, label, icon, url_pattern, is_active, sort_order, created_at) VALUES ('facebook', 'Facebook', 'facebook', 'https://facebook.com/{username}', true, 2, '2025-11-26 05:21:44');
INSERT INTO platform.social_platforms (value, label, icon, url_pattern, is_active, sort_order, created_at) VALUES ('instagram', 'Instagram', 'instagram', 'https://instagram.com/{username}', true, 3, '2025-11-26 05:21:44');
INSERT INTO platform.social_platforms (value, label, icon, url_pattern, is_active, sort_order, created_at) VALUES ('linkedin', 'LinkedIn', 'linkedin', 'https://linkedin.com/in/{username}', true, 4, '2025-11-26 05:21:44');
INSERT INTO platform.social_platforms (value, label, icon, url_pattern, is_active, sort_order, created_at) VALUES ('tiktok', 'TikTok', 'tiktok', 'https://tiktok.com/@{username}', true, 5, '2025-11-26 05:21:44');
INSERT INTO platform.social_platforms (value, label, icon, url_pattern, is_active, sort_order, created_at) VALUES ('youtube', 'YouTube', 'youtube', 'https://youtube.com/@{username}', true, 6, '2025-11-26 05:21:44');
INSERT INTO platform.social_platforms (value, label, icon, url_pattern, is_active, sort_order, created_at) VALUES ('github', 'GitHub', 'github', 'https://github.com/{username}', true, 7, '2025-11-26 05:21:44');
INSERT INTO platform.social_platforms (value, label, icon, url_pattern, is_active, sort_order, created_at) VALUES ('pinterest', 'Pinterest', 'pinterest', 'https://pinterest.com/{username}', true, 8, '2025-11-26 05:21:44');
INSERT INTO platform.social_platforms (value, label, icon, url_pattern, is_active, sort_order, created_at) VALUES ('snapchat', 'Snapchat', 'snapchat', 'https://snapchat.com/add/{username}', true, 9, '2025-11-26 05:21:44');


--
-- Data for Name: status_types; Type: TABLE DATA; Schema: platform; Owner: base_mcp_dev
--

INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('active', 'Active', 'entity', '#22c55e', false, true, 1, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('suspended', 'Suspended', 'entity', '#f59e0b', false, true, 2, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('pending', 'Pending', 'entity', '#3b82f6', false, true, 3, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('trial', 'Trial', 'entity', '#8b5cf6', false, true, 4, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('canceled', 'Canceled', 'entity', '#ef4444', true, true, 5, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('closed', 'Closed', 'entity', '#6b7280', true, true, 6, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('pending_payment', 'Pending Payment', 'transaction', '#f59e0b', false, true, 10, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('processing', 'Processing', 'transaction', '#3b82f6', false, true, 11, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('succeeded', 'Succeeded', 'transaction', '#22c55e', true, true, 12, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('failed', 'Failed', 'transaction', '#ef4444', true, true, 13, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('refunded', 'Refunded', 'transaction', '#6b7280', true, true, 14, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('partially_refunded', 'Partially Refunded', 'transaction', '#f59e0b', false, true, 15, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('draft', 'Draft', 'order', '#6b7280', false, true, 20, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('pending_fulfillment', 'Pending Fulfillment', 'order', '#f59e0b', false, true, 21, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('fulfilled', 'Fulfilled', 'order', '#22c55e', false, true, 22, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('shipped', 'Shipped', 'order', '#3b82f6', false, true, 23, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('delivered', 'Delivered', 'order', '#22c55e', true, true, 24, '2025-11-26 05:21:44');
INSERT INTO platform.status_types (value, label, category, color, is_final, is_active, sort_order, created_at) VALUES ('returned', 'Returned', 'order', '#ef4444', true, true, 25, '2025-11-26 05:21:44');


--
-- PostgreSQL database dump complete
--


