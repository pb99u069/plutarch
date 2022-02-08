{-# LANGUAGE QuantifiedConstraints #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Plutarch.Bool (
  PBool (..),
  PEq (..),
  POrd (..),
  fromBuiltinBool,
  pif,
  pif',
  pnot,
  (#&&),
  (#||),
  por,
  pand,
  pand',
  por',
) where

import Plutarch.Internal.Other (
  DerivePNewtype,
  PDelayed,
  PlutusType (PInner, pcon', pmatch'),
  S,
  Term,
  pcon,
  pdelay,
  pforce,
  phoistAcyclic,
  plam,
  pmatch,
  pto,
  (#),
  type (:-->),
 )
import Plutarch.Unsafe (punsafeBuiltin)
import qualified PlutusCore as PLC

-- | Plutus 'BuiltinBool'
data PBool (s :: S) = PTrue | PFalse

instance PlutusType PBool where
  type PInner PBool a = PDelayed a :--> PDelayed a :--> PDelayed a
  pcon' PTrue = plam const
  pcon' PFalse = plam (flip const)
  pmatch' :: Term s (PDelayed a :--> PDelayed a :--> PDelayed a) -> (PBool s -> Term s a) -> Term s a
  pmatch' b f = pforce $ b # pdelay (f PTrue) # pdelay (f PFalse)

class PEq t where
  (#==) :: Term s t -> Term s t -> Term s PBool

infix 4 #==

class POrd t where
  (#<=) :: Term s t -> Term s t -> Term s PBool
  (#<) :: Term s t -> Term s t -> Term s PBool

infix 4 #<=
infix 4 #<

instance PEq b => PEq (DerivePNewtype a b) where
  x #== y = pto x #== pto y

instance POrd b => POrd (DerivePNewtype a b) where
  x #<= y = pto x #<= pto y
  x #< y = pto x #< pto y

fromBuiltinBool :: Term s (PBool :--> PBool)
fromBuiltinBool = phoistAcyclic $ pforce $ punsafeBuiltin PLC.IfThenElse

{- | Strict version of 'pif'.
 Emits slightly less code.
-}
pif' :: Term s (PBool :--> a :--> a :--> a)
pif' = plam pif

-- | Lazy if-then-else.
pif :: Term s PBool -> Term s a -> Term s a -> Term s a
pif b case_true case_false = pmatch b $ \case
  PTrue -> case_true
  PFalse -> case_false

-- | Boolean negation for 'PBool' terms.
pnot :: Term s (PBool :--> PBool)
pnot = phoistAcyclic $ plam $ \x -> pif x (pcon PFalse) $ pcon PTrue

-- | Lazily evaluated boolean and for 'PBool' terms.
infixr 3 #&&

(#&&) :: Term s PBool -> Term s PBool -> Term s PBool
x #&& y = pforce $ pand # x # pdelay y

-- | Lazily evaluated boolean or for 'PBool' terms.
infixr 2 #||

(#||) :: Term s PBool -> Term s PBool -> Term s PBool
x #|| y = pforce $ por # x # pdelay y

-- | Hoisted, Plutarch level, lazily evaluated boolean and function.
pand :: Term s (PBool :--> PDelayed PBool :--> PDelayed PBool)
pand = phoistAcyclic $ plam $ \x y -> pif' # x # y # (phoistAcyclic $ pdelay $ pcon PFalse)

-- | Hoisted, Plutarch level, strictly evaluated boolean and function.
pand' :: Term s (PBool :--> PBool :--> PBool)
pand' = phoistAcyclic $ plam $ \x y -> pif' # x # y # (pcon PFalse)

-- | Hoisted, Plutarch level, lazily evaluated boolean or function.
por :: Term s (PBool :--> PDelayed PBool :--> PDelayed PBool)
por = phoistAcyclic $ plam $ \x y -> pif' # x # (phoistAcyclic $ pdelay $ pcon PTrue) # y

-- | Hoisted, Plutarch level, strictly evaluated boolean or function.
por' :: Term s (PBool :--> PBool :--> PBool)
por' = phoistAcyclic $ plam $ \x y -> pif' # x # (pcon PTrue) # y
