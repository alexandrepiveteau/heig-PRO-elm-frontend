module Page.Logout exposing
    ( Model
    , update, view
    , init, toSession
    )

{-| A page module that displays nothing, logs the user out, and redirects him to the home page


# TEA

@docs Model
@docs update, view


# functions

@docs init, toSession

-}

import Api
import Cmd.Extra exposing (withCmds, withNoCmd)
import Html exposing (Html)
import Route
import Session exposing (Session)


type alias Model =
    Session


{-| Returns the session of the logout page
-}
toSession : Model -> Session
toSession =
    identity


init : Session -> ( Model, Cmd Never )
init session =
    (Session.guest <| Session.sessionNavKey session)
        |> withCmds
            [ Api.storeCredentialsClear
            , Route.replaceUrl (Session.sessionNavKey session) Route.Home
            ]


update : msg -> Model -> ( Model, Cmd Never )
update _ model =
    model |> withNoCmd


view : Model -> List (Html Never)
view _ =
    []
