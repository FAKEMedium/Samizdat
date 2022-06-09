SET search_path = public,pg_catalog,web,account,stats;

DROP INDEX IF EXISTS ip_ix;

ALTER TABLE web.comment
    DROP CONSTRAINT resource_fk;
ALTER TABLE web.uri
    DROP CONSTRAINT resource_fk;
ALTER TABLE web.menuitem
    DROP CONSTRAINT uri_fk;
ALTER TABLE public.state
    DROP CONSTRAINT country_fk;
ALTER TABLE public.vatrate
    DROP CONSTRAINT country_fk;
ALTER TABLE public.countryname
    DROP CONSTRAINT country_fk;
ALTER TABLE public.statename
    DROP CONSTRAINT state_fk;
ALTER TABLE public.languagename
    DROP CONSTRAINT language_fk;
ALTER TABLE public.statename
    DROP CONSTRAINT language_fk;
ALTER TABLE public.countryname
    DROP CONSTRAINT language_fk;
ALTER TABLE account.password
    DROP CONSTRAINT user_fk;
ALTER TABLE account.login
    DROP CONSTRAINT user_fk;
ALTER TABLE public.languagevariant
    DROP CONSTRAINT language_fk;
ALTER TABLE public.exchangerate
    DROP CONSTRAINT currency_fk;
ALTER TABLE public.currencyname
    DROP CONSTRAINT language_fk;
ALTER TABLE public.currencyname
    DROP CONSTRAINT currency_fk;
ALTER TABLE public.addressformat
    DROP CONSTRAINT country_fk;
ALTER TABLE web.resource
    DROP CONSTRAINT language_fk;
ALTER TABLE web.menuitem
    DROP CONSTRAINT menu_fk;
ALTER TABLE account.rolename
    DROP CONSTRAINT language_fk;
ALTER TABLE account.rolename
    DROP CONSTRAINT role_fk;
ALTER TABLE account.roleuser
    DROP CONSTRAINT role_fk;
ALTER TABLE account.roleuser
    DROP CONSTRAINT user_fk;
ALTER TABLE account.presentation
    DROP CONSTRAINT user_fk;
ALTER TABLE account.presentation
    DROP CONSTRAINT language_fk;
ALTER TABLE account.image
    DROP CONSTRAINT user_fk;
ALTER TABLE web.resource
    DROP CONSTRAINT template_fk;
ALTER TABLE account.displayfield
    DROP CONSTRAINT user_fk;
ALTER TABLE account."user"
    DROP CONSTRAINT contact_fk;
ALTER TABLE public.country
    DROP CONSTRAINT continent_fk;
ALTER TABLE account.contact
    DROP CONSTRAINT language_fk;
ALTER TABLE account.contact
    DROP CONSTRAINT country_fk;
ALTER TABLE account.contact
    DROP CONSTRAINT state_fk;
ALTER TABLE web.resource
    DROP CONSTRAINT parent_fk;
ALTER TABLE web.resource
    DROP CONSTRAINT resourcealias_fk;
ALTER TABLE web.resource
    DROP CONSTRAINT contenttype_fk;
ALTER TABLE web.resource
    DROP CONSTRAINT owner_fk;
ALTER TABLE web.resource
    DROP CONSTRAINT creator_fk;
ALTER TABLE web.resource
    DROP CONSTRAINT publisher_fk;
ALTER TABLE web.menuitem
    DROP CONSTRAINT parent_fk;
ALTER TABLE web.comment
    DROP CONSTRAINT parent_fk;
ALTER TABLE account.message
    DROP CONSTRAINT recipient_fk;
ALTER TABLE account.message
    DROP CONSTRAINT sender_fk;
ALTER TABLE account.userban
    DROP CONSTRAINT banner_id;
ALTER TABLE account.userban
    DROP CONSTRAINT banned_id;
ALTER TABLE account."group"
    DROP CONSTRAINT creator_fk;
ALTER TABLE account."group"
    DROP CONSTRAINT updater_fk;
ALTER TABLE account.usergroup
    DROP CONSTRAINT user_fk;
ALTER TABLE account.usergroup
    DROP CONSTRAINT group_fk;



DROP TABLE IF EXISTS account.contact;
DROP TABLE IF EXISTS account.password;
DROP TABLE IF EXISTS account.role;
DROP TABLE IF EXISTS web.resource;
DROP TABLE IF EXISTS web.menuitem;
DROP TABLE IF EXISTS web.contenttype;
DROP TABLE IF EXISTS web.comment;
DROP TABLE IF EXISTS web.menu;
DROP TABLE IF EXISTS web.uri;
DROP TABLE IF EXISTS account.message;
DROP TABLE IF EXISTS account.userban;
DROP TABLE IF EXISTS web.context;
DROP TABLE IF EXISTS public.country;
DROP TABLE IF EXISTS public.vatrate;
DROP TABLE IF EXISTS public.state;
DROP TABLE IF EXISTS account.loginfailure;
DROP TABLE IF EXISTS public.language;
DROP TABLE IF EXISTS public.languagename;
DROP TABLE IF EXISTS public.countryname;
DROP TABLE IF EXISTS public.statename;
DROP TABLE IF EXISTS account."user";
DROP TABLE IF EXISTS public.languagevariant;
DROP TABLE IF EXISTS web.setting;
DROP TABLE IF EXISTS account.login;
DROP TABLE IF EXISTS public.exchangerate;
DROP TABLE IF EXISTS public.currency;
DROP TABLE IF EXISTS public.currencyname;
DROP TABLE IF EXISTS public.addressformat;
DROP TABLE IF EXISTS account.rolename;
DROP TABLE IF EXISTS account.roleuser;
DROP TABLE IF EXISTS account.presentation;
DROP TABLE IF EXISTS account.image;
DROP TABLE IF EXISTS web.template;
DROP TABLE IF EXISTS account.displayfield;
DROP TABLE IF EXISTS account."group";
DROP TABLE IF EXISTS account.usergroup;
DROP TABLE IF EXISTS public.continent;
DROP TABLE IF EXISTS stats.counter;
DROP TABLE IF EXISTS stats.referrer;
DROP TABLE IF EXISTS stats.visitcache;

DROP TYPE IF EXISTS public."position";

DROP SCHEMA IF EXISTS stats;
DROP SCHEMA IF EXISTS web;
DROP SCHEMA IF EXISTS account;