﻿open Core.Std
open Async.Std
open Cow
open Opium.Std

<% _.each(entities, function (entity) { %>
module <%= _.capitalize(entity.name) %> = struct
  (* this hack is needed because cow is relying on functions shadowed
     by core *)
  open Caml
  type <%= entity.name %> = {
    (* this id is a hack as __id__ is generated by orm;
       it is only used for json *)
    mutable id: int64 option;
    <% _.each(entity.attrs, function (attr) { %>
    mutable <%= attr.attrName %>: <%= attr.attrImplType %> <% if (attr.required) { %>option<% }; %>;<% }); %>
  } with json, orm
end<% }); %>

let db_name = "/tmp/my.db"

let get_index = get "/" begin fun req ->
  let location = Cohttp.Header.init_with "Location" "/public/index.html" in
  respond ~headers:location ~code:`Found (`String "") |> return
end

<% _.each(entities, function (entity) { %>
let get_<%= pluralize(entity.name) %> = get "/<%= baseName %>/<%= pluralize(entity.name) %>" begin fun req ->
  let db = <%= _.capitalize(entity.name) %>.<%= entity.name %>_init db_name in
  let rows = <%= _.capitalize(entity.name) %>.<%= entity.name %>_get db in
  let json = List.map rows (fun x ->
    x.id <- Some(<%= _.capitalize(entity.name) %>.<%= entity.name %>_id db x |> <%= _.capitalize(entity.name) %>.ORMID_<%= entity.name %>.to_int64);
    Json.to_string (<%= _.capitalize(entity.name) %>.json_of_<%= entity.name %> x)
  ) in
  let content_type ct = Cohttp.Header.init_with "Content-Type" ct in
  let json_header = content_type "application/json" in
  Response.of_string_body ~headers:json_header ("[" ^ (String.concat ~sep:", " json) ^ "]") |> return
end

let get_<%= entity.name %> = get "/<%= baseName %>/<%= pluralize(entity.name) %>/:id" begin fun req ->
  let id = "id" |> param req |> Int64.of_string in
  let db = <%= _.capitalize(entity.name) %>.<%= entity.name %>_init db_name in
  let row = <%= _.capitalize(entity.name) %>.<%= entity.name %>_get_by_id (`Eq (<%= _.capitalize(entity.name) %>.ORMID_<%= entity.name %>.of_int64 id)) db in
  row.id <- Some(id);
  `Json (<%= _.capitalize(entity.name) %>.json_of_<%= entity.name %> row) |> respond'
end

let post_<%= entity.name %> = post "/<%= baseName %>/<%= pluralize(entity.name) %>" begin fun req ->
  App.json_of_body_exn req >>| fun json ->
  let db = <%= _.capitalize(entity.name) %>.<%= entity.name %>_init db_name in
  let row = <%= _.capitalize(entity.name) %>.<%= entity.name %>_of_json json in
  <%= _.capitalize(entity.name) %>.<%= entity.name %>_save db row;
  row.id <- Some(<%= _.capitalize(entity.name) %>.<%= entity.name %>_id db row |> <%= _.capitalize(entity.name) %>.ORMID_<%= entity.name %>.to_int64);
  respond (`Json (<%= _.capitalize(entity.name) %>.json_of_<%= entity.name %> row))
end

let put_<%= entity.name %> = put "/<%= baseName %>/<%= pluralize(entity.name) %>/:id" begin fun req ->
  App.json_of_body_exn req >>| fun json ->
  let id = "id" |> param req |> Int64.of_string in
  let db = <%= _.capitalize(entity.name) %>.<%= entity.name %>_init db_name in
  let row = <%= _.capitalize(entity.name) %>.<%= entity.name %>_get_by_id (`Eq (<%= _.capitalize(entity.name) %>.ORMID_<%= entity.name %>.of_int64 id)) db in
  let body = <%= _.capitalize(entity.name) %>.<%= entity.name %>_of_json json in
  <% _.each(entity.attrs, function (attr) { %>
  row.<%= attr.attrName %> <- body.<%= attr.attrName %>;<% }); %>
  <%= _.capitalize(entity.name) %>.<%= entity.name %>_save db row;
  row.id <- Some(<%= _.capitalize(entity.name) %>.<%= entity.name %>_id db row |> <%= _.capitalize(entity.name) %>.ORMID_<%= entity.name %>.to_int64);
  respond (`Json (<%= _.capitalize(entity.name) %>.json_of_<%= entity.name %> row))
end

let delete_<%= entity.name %> = delete "/<%= baseName %>/<%= pluralize(entity.name) %>/:id" begin fun req ->
  let id = "id" |> param req |> Int64.of_string in
  let db = <%= _.capitalize(entity.name) %>.<%= entity.name %>_init db_name in
  let row = <%= _.capitalize(entity.name) %>.<%= entity.name %>_get_by_id (`Eq (<%= _.capitalize(entity.name) %>.ORMID_<%= entity.name %>.of_int64 id)) db in
  <%= _.capitalize(entity.name) %>.<%= entity.name %>_delete db row;
  `String "" |> respond'
end
<% }); %>

let _ =
  App.app
  |> get_index
  <% _.each(entities, function (entity) { %>
  |> get_<%= pluralize(entity.name) %>
  |> get_<%= entity.name %>
  |> post_<%= entity.name %>
  |> put_<%= entity.name %>
  |> delete_<%= entity.name %><% }); %>
  |> middleware (Middleware_pack.static ~local_path:"./public" ~uri_prefix:"/public")
  |> App.port 3000
  |> App.start

