section \<open> Fibonacci Circus Model \<close>

theory Fib
  imports "../ITree_Circus"
begin lit_vars

alphabet FibState = 
  x :: "nat"
  y :: "nat"

instantiation FibState_ext :: (default) default
begin
  definition default_FibState_ext :: "'a FibState_scheme" where
    "default_FibState_ext = FibState.extend 
      (FibState.make 0 0) default"

instance ..
end

chantype chan =
  out :: "nat"

(* Can we instantiate equal manually?
instantiation chan :: equal
begin
  definition equal_chan :: "chan \<Rightarrow> chan \<Rightarrow> bool"
    where "equal_chan xx yy = True"

instance sledgehammer
end
*)

definition Init :: "FibState subst" where
  "Init = [ x \<leadsto> 0, y \<leadsto> 0]"

definition 
  "InitFib = out!(1) \<rightarrow> out!(1) \<rightarrow> (x := 1 \<Zcomp> y := 1)"

definition
  "OutFib = out!(x+y) \<rightarrow> (\<langle>[ x \<leadsto> y, y \<leadsto> x+y]\<rangle>\<^sub>a)"

text \<open> Use of (OutFib \<box> Stop), instead of OutFib, is just for the sake of 
generating of chan_equal, which will be used by simulate in generated haskell
 code.\<close>
definition Fib :: "chan process" where 
"Fib = proc Init (InitFib \<Zcomp> loop (OutFib \<box> Stop))"

(*
print_codeproc
code_thms Fib
*)
(* definition simulate where "simulate = True" *)

code_printing code_module "Simulate" \<rightharpoonup> (Haskell)
\<open>module Simulate (simulate) where

data Itree a b = Ret b | Sil (Itree a b) | Vis (Pfun a (Itree a b));
data Pfun a b = Pfun_of_alist [(a, b)] | Pfun_of_map (a -> Maybe b);

simulate_cnt :: (Eq e, Prelude.Show e, Prelude.Read e, Prelude.Show s) => Prelude.Int -> Itree e s -> Prelude.IO ();
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
  do { Prelude.putStrLn ("Events: " ++ Prelude.show (map fst m));
       e <- Prelude.getLine;
       case (Prelude.reads e) of
         []       -> do { Prelude.putStrLn "No parse"; simulate_cnt n t }
         [(v, _)] -> case (Prelude.lookup v m) of
                       Nothing -> do { Prelude.putStrLn "Rejected"; simulate_cnt n t }
                       Just k -> simulate_cnt 0 k
     };

simulate :: (Eq e, Prelude.Show e, Prelude.Read e, Prelude.Show s) => Itree e s -> Prelude.IO ();
simulate = simulate_cnt 0;\<close>

code_reserved Haskell Simulate

export_code Fib in Haskell module_name Fib (string_classes)

end