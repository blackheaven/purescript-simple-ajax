module Simple.Ajax
  ( simpleRequest, simpleRequest_
  , SimpleRequest, SimpleRequestRow
  , postR, post, postR_, post_, postH, postH_, postRH, postRH_
  , putR, put, putR_, put_
  , deleteR, delete, deleteR_, delete_
  , patchR, patch, patchR_, patch_
  , getR, get
  , handleResponse, handleResponse_
  , module Simple.Ajax.Errors
  ) where

import Prelude

import Affjax (Response, URL, defaultRequest, request, Error, printError)
import Affjax.RequestBody (RequestBody)
import Affjax.RequestBody as RequestBody
import Affjax.RequestHeader (RequestHeader(..))
import Affjax.ResponseFormat (ResponseFormat)
import Affjax.ResponseFormat as ResponseFormat
import Affjax.ResponseHeader (ResponseHeader)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.HTTP.Method (CustomMethod, Method(..))
import Data.Maybe (Maybe(..))
import Data.MediaType (MediaType(..))
import Data.Time.Duration (Milliseconds)
import Data.Tuple (Tuple(..), snd)
import Data.Variant (expand, inj)
import Effect.Aff (Aff)
import Foreign (Foreign)
import Prim.Row as Row
import Record as Record
import Simple.Ajax.Errors (HTTPError, AjaxError, _parseError, _badRequest, _unAuthorized, _forbidden, _notFound, _methodNotAllowed, _formatError, _serverError, mapBasicError, parseError, statusOk)
import Simple.JSON (class ReadForeign, class WriteForeign, readJSON, writeJSON)

handleResponseH :: 
  forall b.
  ReadForeign b =>
  Either Error (Response String) ->
  Either AjaxError (Tuple (Array ResponseHeader) b)
handleResponseH res = case res of 
  Left e -> Left $ inj _serverError $ printError e
  Right response
        | statusOk response.status -> (Tuple response.headers) <$> (lmap (expand <<< parseError) (readJSON response.body))
        | otherwise -> Left $ expand $ mapBasicError response.status response.body

handleResponse ::
  forall b.
  ReadForeign b =>
  Either Error (Response String) ->
  Either AjaxError b
handleResponse res = snd <$> (handleResponseH res)


handleResponseH_ ::
  Either Error (Response String) ->
  Either HTTPError (Tuple (Array ResponseHeader) Unit)
handleResponseH_ res = case res of
  Left e -> Left $ inj _serverError $ printError e
  Right response
        | statusOk response.status -> Right (Tuple response.headers unit)
        | otherwise -> Left $ expand $ mapBasicError response.status response.body

handleResponse_ ::
  Either Error (Response String) ->
  Either HTTPError Unit
handleResponse_ res = snd <$> (handleResponseH_ res)

-- | Writes the contest as JSON.
writeContent ::
  forall a.
  WriteForeign a =>
  Maybe a ->
  Maybe RequestBody
writeContent a = RequestBody.string <<< writeJSON <$> a

-- | An utility method to build requests.
defaults ::
  forall rall rsub rx.
  Row.Union rsub rall rx =>
  Row.Nub rx rall =>
  { | rall } ->
  { | rsub } ->
  { | rall }
defaults = flip Record.merge

-- | The rows of a `Request a`
type RequestRow a = ( method          :: Either Method CustomMethod
                    , url             :: URL
                    , headers         :: Array RequestHeader
                    , content         :: Maybe RequestBody
                    , username        :: Maybe String
                    , password        :: Maybe String
                    , withCredentials :: Boolean
                    , responseFormat  :: ResponseFormat a
                    , timeout         :: Maybe Milliseconds
                    )

type SimpleRequestRow = ( headers         :: Array RequestHeader
                        , username        :: Maybe String
                        , password        :: Maybe String
                        , withCredentials :: Boolean
                        )

-- | A Request object with only the allowed fields.
type SimpleRequest = Record SimpleRequestRow


defaultSimpleRequest :: Record (RequestRow String)
defaultSimpleRequest = Record.merge { responseFormat : ResponseFormat.string
                                    , headers : [ Accept (MediaType "application/json") ]
                                    } defaultRequest


-- | Takes a subset of a `SimpleRequest` and uses it to
-- | override the fields of the defaultRequest
buildRequest ::
  forall r rx t.
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  { | r } ->
  Record (RequestRow String)
buildRequest = defaults defaultSimpleRequest

-- | Makes an HTTP request and tries to parse the response json.
-- |
-- | Helper methods are provided for the most common requests.
simpleRequest ::
  forall a b r rx t.
  WriteForeign a =>
  ReadForeign b =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  Either Method CustomMethod ->
  { | r } ->
  URL ->
  Maybe a ->
  Aff (Either AjaxError b)
simpleRequest method r url content = do
  let req = (buildRequest r) { method = method
                             , url = url
                             , content = writeContent content
                             }
  res <- request req
  pure $ handleResponse res



-- | Makes an HTTP request and tries to parse the response json.
-- |
-- | Helper methods are provided for the most common requests.
simpleRequest' ::
  forall a r rx t.
  WriteForeign a =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  Either Method CustomMethod ->
  { | r } ->
  URL ->
  Maybe a ->
  Aff (Either Error (Response String))
simpleRequest' method r url content = do
  let req = (buildRequest r) { method = method
                             , url = url
                             , content = writeContent content
                             }
  request req
  
-- | Makes an HTTP request ignoring the response payload.
-- |
-- | Helper methods are provided for the most common requests.

  
simpleRequest_ ::
  forall a r rx t.
  WriteForeign a =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  Either Method CustomMethod ->
  { | r } ->
  URL ->
  Maybe a ->
  Aff (Either HTTPError Unit)
simpleRequest_ m r u a = handleResponse_ <$> (simpleRequest' m r u a)

simpleRequestH_ ::
  forall a r rx t.
  WriteForeign a =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  Either Method CustomMethod ->
  { | r } ->
  URL ->
  Maybe a ->
  Aff (Either HTTPError (Tuple (Array ResponseHeader) Unit))
simpleRequestH_ m r u a = handleResponseH_ <$> (simpleRequest' m r u a)


simpleRequestH ::
  forall a b r rx t.
  WriteForeign a =>
  ReadForeign b =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  Either Method CustomMethod ->
  { | r } ->
  URL ->
  Maybe a ->
  Aff (Either AjaxError (Tuple (Array ResponseHeader) b))
simpleRequestH m r u a = handleResponseH <$> (simpleRequest' m r u a)
 
-- | Makes a `GET` request, taking a subset of a `SimpleRequest` and an `URL` as arguments
-- | and then tries to parse the response json.
getR ::
  forall b r rx t.
  ReadForeign b =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  { | r } ->
  URL ->
  Aff (Either AjaxError b)
getR r url = do
  let req = (buildRequest r) { method = Left GET
                             , url = url
                             , responseFormat = ResponseFormat.string
                             }
  res <- request req
  pure $ handleResponse res


-- | Makes a `GET` request, taking an `URL` as argument
-- | and then tries to parse the response json.
get ::
  forall b.
  ReadForeign b =>
  URL ->
  Aff (Either AjaxError b)
get = getR {} -- defaultSimpleRequest

-- | Makes a `POST` request, taking a subset of a `SimpleRequest`, an `URL` and an optional payload
-- | and then tries to parse the response json.
postR :: forall a b r rx t.
  WriteForeign a =>
  ReadForeign b =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  { | r } ->
  URL ->
  Maybe a ->
  Aff (Either AjaxError b)
postR = simpleRequest (Left POST)

-- | Makes a `POST` request, taking a subset of a `SimpleRequest`, an `URL` and an optional payload
-- | and then tries to parse the response json, and provides the response headers.
postRH :: forall a b r rx t.
  WriteForeign a =>
  ReadForeign b =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  { | r } ->
  URL ->
  Maybe a ->
  Aff (Either AjaxError (Tuple (Array ResponseHeader) b))
postRH = simpleRequestH (Left POST)


-- | Makes a `POST` request, taking an `URL` and an optional payload
-- | trying to parse the response json.
post ::
  forall a b.
  WriteForeign a =>
  ReadForeign b =>
  URL ->
  Maybe a ->
  Aff (Either AjaxError b)
post = postR {}

-- | Makes a `POST` request, taking an `URL` and an optional payload
-- | trying to parse the response json.
postH ::
  forall a b.
  WriteForeign a =>
  ReadForeign b =>
  URL ->
  Maybe a ->
  Aff (Either AjaxError (Tuple (Array ResponseHeader) b))
postH = postRH {}


-- | Makes a `POST` request, taking a subset of a `SimpleRequest`, an `URL` and an optional payload,
-- | ignoring the response payload.
postR_ ::
  forall a r rx t.
  WriteForeign a =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  { | r } ->
  URL ->
  Maybe a ->
  Aff (Either HTTPError Unit)
postR_ = simpleRequest_ (Left POST)

-- | Makes a `POST` request, taking a subset of a `SimpleRequest`, an `URL` and an optional payload,
-- | ignoring the response payload.
postRH_ ::
  forall a r rx t.
  WriteForeign a =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  { | r } ->
  URL ->
  Maybe a ->
  Aff (Either HTTPError (Tuple (Array ResponseHeader) Unit))
postRH_ = simpleRequestH_ (Left POST)


-- | Makes a `POST` request, taking an `URL` and an optional payload,
-- | ignoring the response payload.
post_ ::
  forall a.
  WriteForeign a =>
  URL ->
  Maybe a ->
  Aff (Either HTTPError Unit)
post_ = postR_ {}

-- | Makes a `POST` request, taking an `URL` and an optional payload,
-- | ignoring the response payload.
postH_ ::
  forall a.
  WriteForeign a =>
  URL ->
  Maybe a ->
  Aff (Either HTTPError (Tuple (Array ResponseHeader) Unit))
postH_ = postRH_ {}


-- | Makes a `PUT` request, taking a subset of a `SimpleRequest`, an `URL` and an optional payload
-- | and then tries to parse the response json.
putR :: forall a b r rx t.
  WriteForeign a =>
  ReadForeign b =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  { | r } ->
  URL ->
  Maybe a ->
  Aff (Either AjaxError b)
putR = simpleRequest (Left PUT)

-- | Makes a `PUT` request, taking an `URL` and an optional payload
-- | trying to parse the response json.
put ::
  forall a b.
  WriteForeign a =>
  ReadForeign b =>
  URL ->
  Maybe a ->
  Aff (Either AjaxError b)
put = putR {}

-- | Makes a `PUT` request, taking a subset of a `SimpleRequest`, an `URL` and an optional payload,
-- | ignoring the response payload.
putR_ ::
  forall a r rx t.
  WriteForeign a =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  { | r } ->
  URL ->
  Maybe a ->
  Aff (Either HTTPError Unit)
putR_ = simpleRequest_ (Left PUT)

-- | Makes a `PUT` request, taking an `URL` and an optional payload,
-- | ignoring the response payload.
put_ ::
  forall a.
  WriteForeign a =>
  URL ->
  Maybe a ->
  Aff (Either HTTPError Unit)
put_ = putR_ {}

-- | Makes a `PATCH` request, taking a subset of a `SimpleRequest`, an `URL` and an optional payload
-- | and then tries to parse the response json.
patchR :: forall a b r rx t.
  WriteForeign a =>
  ReadForeign b =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  { | r } ->
  URL ->
  Maybe a ->
  Aff (Either AjaxError b)
patchR = simpleRequest (Left PATCH)

-- | Makes a `PATCH` request, taking an `URL` and an optional payload
-- | trying to parse the response json.
patch ::
  forall a b.
  WriteForeign a =>
  ReadForeign b =>
  URL ->
  Maybe a ->
  Aff (Either AjaxError b)
patch = patchR {}

-- | Makes a `PATCH` request, taking a subset of a `SimpleRequest`, an `URL` and an optional payload,
-- | ignoring the response payload.
patchR_ ::
  forall a r rx t.
  WriteForeign a =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  { | r } ->
  URL ->
  Maybe a ->
  Aff (Either HTTPError Unit)
patchR_ = simpleRequest_ (Left PATCH)

-- | Makes a `PATCH` request, taking an `URL` and an optional payload,
-- | ignoring the response payload.
patch_ ::
  forall a.
  WriteForeign a =>
  URL ->
  Maybe a ->
  Aff (Either HTTPError Unit)
patch_ = patchR_ {}

-- | Makes a `DELETE` request, taking a subset of a `SimpleRequest` and an `URL`
-- | and then tries to parse the response json.
deleteR :: forall b r rx t.
  ReadForeign b =>
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  { | r } ->
  URL ->
  Aff (Either AjaxError b)
deleteR req url = simpleRequest (Left DELETE) req url (Nothing :: Maybe Foreign)

-- | Makes a `DELETE` request, taking an `URL`
-- | and then tries to parse the response json.
delete ::
  forall b.
  ReadForeign b =>
  URL ->
  Aff (Either AjaxError b)
delete = deleteR {}

-- | Makes a `DELETE` request, taking a subset of a `SimpleRequest` and an `URL`,
-- | ignoring the response payload.
deleteR_ ::
  forall r rx t.
  Row.Union r SimpleRequestRow rx =>
  Row.Union r (RequestRow String) t =>
  Row.Nub rx SimpleRequestRow =>
  Row.Nub t (RequestRow String) =>
  { | r } ->
  URL ->
  Aff (Either HTTPError Unit)
deleteR_ req url = simpleRequest_ (Left DELETE) req url (Nothing :: Maybe Foreign)

-- | Makes a `DELETE` request, taking an `URL`,
-- | ignoring the response payload.
delete_ ::
  URL ->
  Aff (Either HTTPError Unit)
delete_ = deleteR_ {}
