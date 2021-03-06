{-# LANGUAGE DeriveGeneric #-}

{-|
Module      : Types
Description : Type declarations used throughout Bartlett
Copyright   : (c) Nike, Inc., 2016
License     : BSD3
Maintainer  : fernando.freire@nike.com
Stability   : stable

Types and type alises used throughout Bartlett.
-}
module Bartlett.Types (
  -- * Type Aliases
  JenkinsInstance,
  Username,
  Password,
  JobPath,
  JobParameters,
  Profile,
  ConfigPath,
  -- * User types
  BasicAuthUser(..),
  User(..),
  -- * Command-Line Types
  Command(..),
  Options(..),
  -- * Network Types
  StatusResponse(..),
  RequestType(..)
) where

import Data.Aeson (ToJSON, FromJSON)
import Data.ByteString.Lazy.Char8 (ByteString, toStrict)
import GHC.Generics (Generic)
import Network.Wreq (Auth, basicAuth)
import URI.ByteString (URIRef, Absolute)

-- TODO use newtypes!! doesn't require boxing

type JenkinsInstance = URIRef Absolute
-- ^ Base URI for the desired Jenkins instance.
type Username        = ByteString
-- ^ Username to authenticate with against Jenkins.
type Password        = ByteString
-- ^ Password to authenticate with against Jenkins.
type JobPath         = ByteString
-- ^ Slash-delimited string representing the path to the job for the given
-- Jenkins instance.
type JobParameters   = ByteString
-- ^ Comma-separated list of key=value pairs to pass along to the triggered job.
type Profile         = ByteString
-- ^ The profile to use when authenticating against Jenkins.
type ConfigPath      = FilePath
-- ^ The path to the job configuration to upload.

-- | Defines methods for basic authentication
class BasicAuthUser a where
  -- ^ Retrieve the user and password information from the given object and
  -- return an 'Auth' object.
  getBasicAuth :: a -> Auth

-- | Simple representation of a user
data User =
  User Username Password -- ^ Simple representation of a user.

-- | Basic auth implementation for 'User'
instance BasicAuthUser User where
  getBasicAuth (User usr pwd) = basicAuth (toStrict usr) (toStrict pwd)

-- | Represents all available sub-commands for 'Bartlett'.
data Command =
  Info [JobPath]                        -- ^ Retrieve information for the given job.
  | Build JobPath (Maybe JobParameters) -- ^ Build the given job with the given options.
  | Config JobPath (Maybe ConfigPath)   -- ^ Retrieve and upload job configurations.

-- | Represents all available CLI options for 'Bartlett'.
data Options =
  Options (Maybe Username) (Maybe JenkinsInstance) (Maybe Profile) Command

-- | Wrapper around Wreq's 'Status' type.
--
--   At this time 'Data.Aeson' does not support parsing 'ByteString', so accept a
--   'String' instead.
data StatusResponse = StatusResponse {
      statusCode :: Int,      -- ^ Status code for the response
      statusMessage :: String -- ^ Message for the response
    }
  deriving (Eq, Generic, Show)

-- Derived JSON serlializers
instance ToJSON StatusResponse
instance FromJSON StatusResponse

-- | Incomplete sum type for network requests
data RequestType = Get | Post
