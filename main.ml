let main () =
  let dict = Trie.load_from_text_file "csw15.lower" in
  let env = ref (Librepl.new_env dict) in
  Repl.repl env

let _ = Lwt_main.run @@ main ()
