subsection \<open> Simulation Harness \<close>

theory ITree_Simulation
  imports Executable_Universe Channel_Type_Rep "Interaction_Trees.ITree_Extraction" 
  keywords "animate" :: "thy_defn"
begin

text \<open> The following additional constructor for partial functions allows us to request an
  value covered by @{typ uval}. \<close>

definition pfun_of_ufun :: "(uval \<Longrightarrow>\<^sub>\<triangle> 'e) \<Rightarrow> utyp \<Rightarrow> (uval \<Rightarrow> 'b) \<Rightarrow> 'e \<Zpfun> 'b" where
"pfun_of_ufun c t P = (\<lambda> e\<in>{build\<^bsub>c\<^esub> v | v. v \<in> uvals t} \<bullet> P (the (match\<^bsub>c\<^esub> e)))"

lemma map_pfun_pfun_of_ufun [code]: "map_pfun f (pfun_of_ufun c t P) = pfun_of_ufun c t (f \<circ> P)"
  by (simp add: pfun_of_ufun_def pfun_eq_iff)

definition itree_chf :: "uname \<Rightarrow> ('inp::uvals \<times> 'out::uvals \<Longrightarrow>\<^sub>\<triangle> 'e) \<Rightarrow> 'out \<Rightarrow> ('inp \<Rightarrow> ('e, 's) itree) \<Rightarrow> ('e, ('e, 's) itree) chf" where
"itree_chf n c out P = ChanF undefined (n, to_uval out) UTYPE('inp) (P \<circ> from_uval)"

(* The conceptual type for the ITree structure we'd like is as below: *)

typ \<open> ('inp::uvals \<times> 'out::uvals \<Longrightarrow>\<^sub>\<triangle> 'e) \<Rightarrow> 'out \<Rightarrow> ('inp \<Rightarrow> ('e, 's) itree) \<close>

code_datatype pfun_of_alist pfun_of_map pfun_of_ufun pfun_of_chfuns pfun_entries

code_identifier
  code_module ITree_Simulation \<rightharpoonup> (Haskell) Interaction_Trees
| code_module Partial_Fun \<rightharpoonup> (Haskell) Interaction_Trees
| code_module Interaction_Trees \<rightharpoonup> (Haskell) Interaction_Trees

generate_file \<open>code/simulate/Simulate.hs\<close> = \<open>
module Simulate (simulate) where
import Interaction_Trees;
import Executable_Universe;
import Channel_Type_Rep;
import Prelude;
import System.IO;
import Data.Ratio;

-- These library functions help us to trim the "_C" strings from pretty printed events

isPrefixOf              :: (Eq a) => [a] -> [a] -> Bool;
isPrefixOf [] _         =  True;
isPrefixOf _  []        =  False;
isPrefixOf (x:xs) (y:ys)=  x == y && isPrefixOf xs ys;

removeSubstr :: String -> String -> String;
removeSubstr w "" = "";
removeSubstr w s@(c:cs) = (if w `isPrefixOf` s then Prelude.drop (Prelude.length w) s else c : removeSubstr w cs);

instance Show Uval where
  show UnitV = "()"
  show (BoolV x) = show x
  show (IntV x) = show x
  show (RatV x) = show (fromRational x)
  show (StringV x) = show x
  show (EnumV _ x) = x
  show (PairV xy) = show xy
  show (ListV typ xs) = show xs

mk_readUval :: Read a => (a -> Uval) -> String -> IO Uval
mk_readUval f n = 
  do { putStr ("Input <" ++ n ++ "> value: ")
     ; e <- getLine
     ; return (f (read e)) }

readUtyp :: Utyp -> IO Uval
readUtyp BoolT = mk_readUval BoolV "bool"
readUtyp IntT = mk_readUval IntV "int"
readUtyp UnitT = return UnitV

simulate_cnt :: (Eq e, Prelude.Show e, Prelude.Show s) => Prelude.Int -> Itree e s -> Prelude.IO ();
simulate_cnt n (Ret x) = Prelude.putStrLn ("Terminated: " ++ Prelude.show x);
simulate_cnt n (Sil p) = 
  do { if (n == 0) then Prelude.putStrLn "Internal Activity..." else return ();
       if (n >= 20) then do { Prelude.putStr "Many steps (> 20); Continue? [Y/N]"; q <- Prelude.getLine; 
                              if (q == "Y") then simulate_cnt 0 p else Prelude.putStrLn "Ended early.";
                            }
                    else simulate_cnt (n + 1) p
     };
simulate_cnt n (Vis (Pfun_of_alist [])) = Prelude.putStrLn "Deadlocked.";
simulate_cnt n t@(Vis (Pfun_of_alist m)) = 
  do { Prelude.putStrLn ("Events:" ++ Prelude.concat (map (\(n, e) -> " (" ++ Prelude.show n ++ ") " ++ removeSubstr "_C" e ++ ";") (zip [1..] (map (Prelude.show . fst) m))));
       e <- Prelude.getLine;
       if (e == "q" || e == "Q") then
         Prelude.putStrLn "Simulation terminated"
       else
       case (Prelude.reads e) of
         []       -> do { Prelude.putStrLn "No parse"; simulate_cnt n t }
         [(v, _)] -> if (v > Prelude.length m)
                       then do { Prelude.putStrLn "Rejected"; simulate_cnt n t }
                       else simulate_cnt 0 (snd (m !! (v - 1)))
     };                                                            
simulate_cnt n t@(Vis (Pfun_of_ufun chan typ m)) = 
  do { v <- readUtyp typ; 
       simulate_cnt 0 (m v) }
simulate_cnt n (Vis (Pfun_of_chfuns [])) = Prelude.putStrLn "Deadlocked.";
simulate_cnt n t@(Vis (Pfun_of_chfuns m)) =
  do { Prelude.putStrLn ("Events:" ++ Prelude.concat (map (\(i, ChanF c (n, p) _ _) -> " (" ++ show i ++ ") " ++ n ++ " " ++ show p ++ ";") (zip [1..] m)));
       e <- Prelude.getLine;
       if (e == "q" || e == "Q") then
         Prelude.putStrLn "Simulation terminated"
       else
       case (Prelude.reads e) of
         []       -> do { Prelude.putStrLn "No parse"; simulate_cnt n t }
         [(v, _)] -> if (v > Prelude.length m)
                       then do { Prelude.putStrLn "Rejected"; simulate_cnt n t }
                       else let (typ, p) = (\(ChanF _ _ t p) -> (t, p)) (m!!(v - 1)) 
                            in do { val <- readUtyp typ
                                  ; simulate_cnt 0 (p val) } -- Ask for any inputs needed
     };                                                            

simulate :: (Eq e, Prelude.Show e, Prelude.Show s) => Itree e s -> Prelude.IO ();
simulate p = do { hSetBuffering stdout NoBuffering; putStrLn ""; putStrLn "Starting ITree Simulation..."; simulate_cnt 0 p }
\<close>

(* The code below is the case for an opaque map function. It depends on there being a Read instance. *)

(*
simulate_cnt n t@(Vis (Pfun_of_map f)) = 
  do { Prelude.putStr ("Enter an event:");
       e <- Prelude.getLine;
       if (e == "q" || e == "Q") then
         Prelude.putStrLn "Simulation terminated"
       else
       case (Prelude.reads e) of
         []       -> do { Prelude.putStrLn "No parse"; simulate_cnt n t } 
         [(v, _)] -> case f v of
                       Nothing -> do { Prelude.putStrLn "Rejected"; simulate_cnt n t }
                       Just t' -> simulate_cnt 0 t'
     };    
*)

ML \<open> 

structure ITree_Simulator =
struct

structure ISim_Path = Theory_Data
  (type T = Path.T option
   val empty = NONE
   val extend = I
   val merge = fn (_, y) => y);

fun simulator_setup thy = 
  let open Isabelle_System; val tmp = Path.expand (create_tmp_path "itree-simulate" "")
  in case (ISim_Path.get thy) of NONE => () | SOME oldtmp => rm_tree oldtmp;
    make_directory tmp; (tmp, ISim_Path.put (SOME tmp) thy)
  end

fun sim_files_cp ghc tmp = 
  "(fn path => let open Isabelle_System; val path' = Path.append path (Path.make [\"code\", \"simulate\"])" ^
  " in writeln \"Compiling animation...\"; bash (\"cd \" ^ Path.implode path' ^ \"; " ^ ghc ^ " Simulation >> /dev/null\") ; copy_dir path' (Path.explode \"" ^ tmp ^ "\") end)";

open Named_Target

fun firstLower s =
  case String.explode s of [] => "" | c :: cs => String.implode (Char.toLower c :: cs);

fun simulation_file model thy =
  "module Main where \n" ^
  "import Simulate; \n" ^
  "import " ^ thy ^ "; \n" ^
  "main = simulate " ^ firstLower model

fun prep_simulation model thy ctx =
  let open Generated_Files; 
      val (tmp, thy') = simulator_setup (Local_Theory.exit_global ctx);
      val ctx' = Named_Target.theory_init thy'
      val ghc = getenv "ISABELLE_GHC"
      val _ = if (ghc = "") then error "GHC is not set up. Please set the environment variable ISABELLE_GHC." else ()
  in
  generate_file (Path.binding0 (Path.make ["code", "simulate", "Simulation.hs"]), (Input.string (simulation_file model thy))) ctx' |>
  (fn ctx' => 
    let val _ = compile_generated_files 
                 ctx'
                 [([], (Local_Theory.exit_global ctx')), ([Path.binding0 (Path.make ["code", "simulate", "Simulate.hs"])], @{theory})] 
                 [] [([Path.binding0 (Path.make ["code", "simulate", "Simulation"])], SOME true)]
                 (Path.binding0 (Path.make []))
                 (Input.string (sim_files_cp ghc (Path.implode tmp)))
    in ctx' end)
  end

fun run_simulation thy =
  
  case ISim_Path.get thy of
    NONE => error "No animation" |
    SOME f => 
      let val p = Path.append f (Path.make ["simulate"])
      in writeln (Active.run_system_shell_command (SOME (Path.implode p)) ("./Simulation") "Start animation") end

fun simulate model thy =
  let val ctx = Named_Target.theory_init thy
      val ctx' =
        (Code_Target.export_code true [Code.read_const (Local_Theory.exit_global ctx) model] [((("Haskell", ""), SOME ({physical = false}, (Path.explode "simulate", Position.none))), [])] ctx)
        |> prep_simulation model (Context.theory_name thy)
  in run_simulation (Local_Theory.exit_global ctx'); (Local_Theory.exit_global ctx')
  end 

end;
\<close>

definition show_channel :: "String.literal \<Rightarrow> 'a::show \<Rightarrow> String.literal" where
"show_channel c p = c + STR '' '' + show p"

ML_file \<open>Show_Channel.ML\<close>

ML \<open>
  Outer_Syntax.command @{command_keyword animate} "animate an ITree"
  (Parse.name >> (fn model => Toplevel.theory (ITree_Simulator.simulate model)));

\<close>

end