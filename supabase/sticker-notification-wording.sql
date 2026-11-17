do $$declare definition text;begin
 select pg_get_functiondef('app_private.complete_chore(uuid,uuid)'::regprocedure) into definition;
 execute replace(definition,' (+1 gold star)',' (+1 sticker)');
end $$;
