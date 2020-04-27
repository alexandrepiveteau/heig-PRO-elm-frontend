module Api.Polls exposing
    ( Poll, PollError(..)
    , getPollList, getPoll, delete, create, update
    , urlParser
    , PollDiscriminator
    )

{-| A module that provides ways to manipulate and to communicate with the
backend about everything polls


# Types

@docs Poll, PollIdentifier, PollError


# Endpoints

@docs getPollList, getPoll, delete, create, update


# urlParser

@docs urlParser

-}

import Api exposing (Credentials, authenticated, get, moderatorId, withPath)
import Http
import Json.Decode exposing (Decoder, field)
import Json.Encode
import Task exposing (Task)
import Url.Parser exposing ((</>), int, s, string)


type PollError
    = GotNotFound
    | GotBadCredentials
    | GotBadNetwork


type alias Poll =
    { idModerator : Int
    , idPoll : Int
    , title : String
    }


type alias PollDiscriminator =
    { idPoll : Int }


{-| A command that will try to request the list of polls existing for a logged
in moderator, and tell what
the issue was if it did not work.
-}
getPollList : Credentials -> (List Poll -> a) -> Task PollError a
getPollList credentials transform =
    let
        path =
            "mod/" ++ String.fromInt (moderatorId credentials) ++ "/poll"
    in
    get
        { body =
            Json.Encode.null
        , endpoint =
            authenticated credentials
                |> withPath path
        , decoder = pollListDecoder
        }
        |> Task.mapError
            (\error ->
                case error of
                    Http.BadStatus 404 ->
                        GotNotFound

                    Http.BadStatus 403 ->
                        GotBadCredentials

                    _ ->
                        GotBadNetwork
            )
        |> Task.map transform


getPoll : Credentials -> PollDiscriminator -> (Poll -> a) -> Task PollError a
getPoll credentials pollDiscriminator transform =
    let
        path =
            "mod/" ++ String.fromInt (Api.moderatorId credentials) ++ "/poll/" ++ String.fromInt pollDiscriminator.idPoll
    in
    Api.get
        { body =
            Json.Encode.null
        , endpoint = authenticated credentials |> withPath path
        , decoder = pollDecoder
        }
        |> Task.mapError
            (\error ->
                case error of
                    Http.BadStatus 403 ->
                        GotBadCredentials

                    _ ->
                        GotBadNetwork
            )
        |> Task.map transform


{-| Deletes a provided poll from the backend, and returns the specified value on success.
-}
delete : Credentials -> Poll -> a -> Task PollError a
delete credentials poll return =
    let
        path =
            "mod/" ++ String.fromInt poll.idModerator ++ "/poll/" ++ String.fromInt poll.idPoll
    in
    Api.delete
        { body = Json.Encode.null
        , endpoint = authenticated credentials |> withPath path
        , decoder = Json.Decode.succeed return
        }
        |> Task.mapError
            (\error ->
                case error of
                    Http.BadStatus 404 ->
                        GotNotFound

                    Http.BadStatus 403 ->
                        GotBadCredentials

                    _ ->
                        GotBadNetwork
            )


{-| Create a poll with a specified title, and returns the created poll on success
-}
create : Credentials -> String -> (Poll -> a) -> Task PollError a
create credentials title transform =
    let
        path =
            "mod/" ++ String.fromInt (Api.moderatorId credentials) ++ "/poll"
    in
    Api.post
        { body =
            Json.Encode.object
                [ ( "title", Json.Encode.string title ) ]
        , endpoint = authenticated credentials |> withPath path
        , decoder = pollDecoder
        }
        |> Task.mapError
            (\error ->
                case error of
                    Http.BadStatus 403 ->
                        GotBadCredentials

                    _ ->
                        GotBadNetwork
            )
        |> Task.map transform


{-| Updates a poll with a specified title, and returns the created poll on success
-}
update : Credentials -> Poll -> String -> (Poll -> a) -> Task PollError a
update credentials poll newTitle transform =
    let
        path =
            "mod/" ++ String.fromInt poll.idModerator ++ "/poll/" ++ String.fromInt poll.idPoll
    in
    Api.put
        { body =
            Json.Encode.object
                [ ( "title", Json.Encode.string newTitle ) ]
        , endpoint = authenticated credentials |> withPath path
        , decoder = pollDecoder
        }
        |> Task.mapError
            (\error ->
                case error of
                    Http.BadStatus 403 ->
                        GotBadCredentials

                    _ ->
                        GotBadNetwork
            )
        |> Task.map transform


pollDecoder : Decoder Poll
pollDecoder =
    Json.Decode.map3 Poll
        (field "idModerator" Json.Decode.int)
        (field "idPoll" Json.Decode.int)
        (field "title" Json.Decode.string)


pollListDecoder : Decoder (List Poll)
pollListDecoder =
    Json.Decode.list <|
        pollDecoder


urlParser : Url.Parser.Parser (PollDiscriminator -> a) a
urlParser =
    Url.Parser.map PollDiscriminator int
