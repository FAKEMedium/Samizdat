-- Add a column for the language of the language name
alter table public.languagename add column if not exists language int not null ;
ALTER TABLE public.languagename
    ADD CONSTRAINT languagename_fk FOREIGN KEY (language)
        REFERENCES public.language (id) MATCH FULL
        ON DELETE SET NULL ON UPDATE CASCADE;
--
insert into public.languagename(id, languagename, languageid, language) values (1, 'English', 1, 1);
insert into public.languagename(id, languagename, languageid, language) values (2, 'svenska', 2, 2);
insert into public.languagename(id, languagename, languageid, language) values (3, 'Swedish', 2, 1);
insert into public.languagename(id, languagename, languageid, language) values (4, 'engelska', 1, 2);