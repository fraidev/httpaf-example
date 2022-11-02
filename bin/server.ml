open Base
module Arg = Caml.Arg

open Httpaf_eio
open Httpaf

let error_handler (_ : Eio.Net.Sockaddr.stream) = Httpaf_examples.Server.error_handler

let request_handler ~u (_ : Eio.Net.Sockaddr.stream) { Gluten.reqd; _ } =
    match Reqd.request reqd  with
    | { Request.meth = `GET; _ } ->
      let response =
        Response.create
          ~headers:(Headers.of_list
            [ "content-type", "text/plain";
            "content-length", "9999999"
            ; "connection", "close"
            ]) `OK
      in
      let result = Caml.Gc.major_slice 2000000000 in
      Caml.Format.eprintf "result: %d@." result;
      Caml.Gc.full_major ();
      (* Caml.Gc.print_stat Caml.stderr; *)
      (* Caml.stderr |> Caml.flush; *)
      Reqd.respond_with_string reqd response (String.make 99999999 'a');
      Eio.Promise.resolve u ()
    | _ ->
      let headers = Headers.of_list [ "connection", "close" ] in
      Reqd.respond_with_string reqd (Response.create ~headers `Method_not_allowed) ""
;;


let log_connection_error ex =
  Eio.traceln "Uncaught exception handling client: %a" Fmt.exn ex

let main port =
  Eio_main.run (fun env ->
  let listen_address = (`Tcp (Eio.Net.Ipaddr.V4.loopback, port)) in
  let network = Eio.Stdenv.net env in
  let handler ~u =
    Server.create_connection_handler ~request_handler:(request_handler ~u) ~error_handler in
  Eio.Switch.run (fun sw ->
    let socket =
      Eio.Net.listen ~reuse_addr:true  ~reuse_port:true ~backlog:5 ~sw
      network
      listen_address
    in
  Stdio.printf "Listening on port %i and echoing POST requests.\n" port;
  Stdio.printf "To send a POST request, try one of the following\n\n";
  Stdio.printf "  echo \"Testing echo POST\" | dune exec examples/async/async_post.exe\n";
  Stdio.printf "  echo \"Testing echo POST\" | dune exec examples/lwt/lwt_post.exe\n";
  Stdio.printf "  echo \"Testing echo POST\" | curl -XPOST --data @- http://localhost:%d\n\n%!" port;
  (* let domain_mgr = Eio.Stdenv.domain_mgr env in *)
  let p, _ = Eio.Promise.create () in
  for _i = 1 to 1 do
    Eio.Fiber.fork_daemon ~sw (fun () ->
      (* Eio.Domain_manager.run domain_mgr (fun () -> *)
        Eio.Switch.run (fun sw ->
          while true do
            Eio.Net.accept_fork socket ~sw ~on_error:log_connection_error (fun client_sock client_addr ->
                let p, u = Eio.Promise.create () in
                handler ~u client_addr client_sock;
                Eio.Promise.await p
                )
          done;
        `Stop_daemon))
      (* ) *)
  done;
  Eio.Promise.await p));

;;

let () =  
  (* Caml.Gc.set { (Caml.Gc.get ()) with space_overhead = 20; max_overhead = 0; verbose = 0x404 }; *)
  let port = ref 8080 in
  Arg.parse
    ["-p", Arg.Set_int port, " Listening port number (8080 by default)"]
    ignore
    "Echoes POST requests. Runs forever.";
  main !port
;;
