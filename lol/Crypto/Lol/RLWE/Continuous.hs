{-|
Module      : Crypto.Lol.RLWE.Continuous
Description : Functions and types for working with continuous ring-LWE samples.
Copyright   : (c) Eric Crockett, 2011-2017
                  Chris Peikert, 2011-2017
License     : GPL-3
Maintainer  : ecrockett0@gmail.com
Stability   : experimental
Portability : POSIX

  \( \def\Z{\mathbb{Z}} \)
  \( \def\R{\mathbb{R}} \)

Functions and types for working with continuous ring-LWE samples.
-}

{-# LANGUAGE ConstraintKinds       #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE RebindableSyntax      #-}
{-# LANGUAGE ScopedTypeVariables   #-}

module Crypto.Lol.RLWE.Continuous where

import Crypto.Lol.Cyclotomic.Language
import Crypto.Lol.Prelude

import Control.Applicative
import Control.Monad.Random

-- | A continuous RLWE sample \( (a,b) \in R_q \times K/(qR) \).  The
-- base type @rrq@ represents \( \R/q\Z \), the additive group of
-- reals modulo \( q \).
type Sample cm zq rrq = (cm zq, cm rrq)

-- | Common constraints for working with continuous RLWE.
type RLWECtx cm zq rrq =
  (Cyclotomic (cm zq), Ring (cm zq), Additive (cm rrq),
   Subgroup zq rrq, FunctorCyc cm zq rrq)

-- | A continuous RLWE sample with the given scaled variance and secret.
sample :: forall rnd v cm zq rrq .
  (RLWECtx cm zq rrq, Random (cm zq), GaussianCyc (cm (LiftOf rrq)),
   Reduce (cm (LiftOf rrq)) (cm rrq), MonadRandom rnd, ToRational v)
  => v -> cm zq -> rnd (Sample cm zq rrq)
{-# INLINABLE sample #-}
sample svar s = let s' = adviseCRT s in do
  a <- getRandom
  e :: cm (LiftOf rrq) <- tweakedGaussian svar
  let as = fmapDec fromSubgroup (a * s')
  return (a, as + reduce e)

-- | The error term of an RLWE sample, given the purported secret.
errorTerm :: (RLWECtx cm zq rrq, FunctorCyc cm rrq (LiftOf rrq), Lift' rrq)
  => cm zq -> Sample cm zq rrq -> cm (LiftOf rrq)
{-# INLINABLE errorTerm #-}
errorTerm s = let s' = adviseCRT s
              in \(a,b) -> liftDec $ b - fmapDec fromSubgroup (a * s')

-- | The 'gSqNorm' of the error term of an RLWE sample, given the
-- purported secret.
errorGSqNorm :: (RLWECtx cm zq rrq, FunctorCyc cm rrq (LiftOf rrq), Lift' rrq,
                 GSqNormCyc cm (LiftOf rrq))
  => cm zq -> Sample cm zq rrq -> LiftOf rrq
{-# INLINABLE errorGSqNorm #-}
errorGSqNorm = (fmap gSqNorm) . errorTerm

-- | A bound such that the 'gSqNorm' of a continuous error generated
-- by 'tweakedGaussian' with scaled variance \(v\) (over the \(m\)th
-- cyclotomic field) is less than the bound except with probability
-- approximately \( \varepsilon \).
errorBound :: (Ord v, Transcendental v, Fact m)
              => v              -- ^ the scaled variance
              -> v              -- ^ \( \varepsilon \)
              -> Tagged m v
errorBound v eps = do
  n <- fromIntegral <$> totientFact
  mhat <- fromIntegral <$> valueHatFact
  let stabilize x =
        let x' = (1/2 + log (2 * pi * x)/2 - log eps/n)/pi
        in if x'-x < 0.0001 then x' else stabilize x'
  return $ mhat * n * v * stabilize (1/(2*pi))
