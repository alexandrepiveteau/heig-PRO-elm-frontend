module Page.Account exposing
    ( Message
    , Model
    , init
    , subscriptions
    , toSession
    , update
    , view
    )

import Api.Account as Api
import Html exposing (Html)
import Html.Attributes as Attribute
import Html.Events as Event
import Route
import Session exposing (Session, Viewer)
import Task exposing (Task)
import Task.Extra



-- MODEL


type alias Model =
    { viewer : Viewer
    , nextUsername : String
    , nextPassword : String
    , error : Maybe Error
    , confirmation : Maybe ( String, String -> Cmd Message )
    }


init : Viewer -> ( Model, Cmd Message )
init viewer =
    ( { viewer = viewer
      , nextUsername = ""
      , nextPassword = ""
      , error = Nothing
      , confirmation = Nothing
      }
    , Cmd.none
    )


toSession : Model -> Session
toSession model =
    Session.toSession model.viewer



-- UPDATE


type Error
    = Cancellation
    | BadCredentials
    | BadCommunication


type Message
    = WriteNewUsername String
    | WriteNewPassword String
    | WriteConfirmationPassword (String -> Cmd Message) String
    | ClickUpdateUsername
    | ClickUpdatePassword
    | ClickDeleteAccount
    | GotError Error
    | NowConfirm (Cmd Message)
    | NowDisconnect


subscriptions : Model -> Sub Message
subscriptions _ =
    Sub.none


update : Message -> Model -> ( Model, Cmd Message )
update message model =
    case message of
        WriteNewUsername username ->
            ( { model | nextUsername = username }, Cmd.none )

        WriteNewPassword password ->
            ( { model | nextPassword = password }, Cmd.none )

        WriteConfirmationPassword command password ->
            ( { model | confirmation = Just ( password, command ) }, Cmd.none )

        ClickUpdateUsername ->
            ( { model | confirmation = Just ( "", updateUsername model ) }, Cmd.none )

        ClickUpdatePassword ->
            ( { model | confirmation = Just ( "", updatePassword model ) }, Cmd.none )

        ClickDeleteAccount ->
            ( { model | confirmation = Just ( "", delete model ) }, Cmd.none )

        GotError error ->
            ( { model | error = Just error, confirmation = Nothing }, Cmd.none )

        NowConfirm command ->
            ( { model | error = Nothing }, command )

        NowDisconnect ->
            ( model
            , Route.replaceUrl
                (Session.viewerNavKey model.viewer)
                Route.Logout
            )



-- EFFECTS


handleError : Api.Error -> Message
handleError error =
    GotError <|
        case error of
            Api.GotNotFound ->
                BadCommunication

            Api.GotInvalidCredentials ->
                BadCredentials

            Api.GotBadNetwork ->
                BadCommunication


handleErrorAndThenDisconnect : Task Api.Error a -> Cmd Message
handleErrorAndThenDisconnect task =
    Task.mapError handleError task
        |> Task.andThen (always <| Task.succeed NowDisconnect)
        |> Task.Extra.execute


updatePassword : Model -> (String -> Cmd Message)
updatePassword model =
    \pwd ->
        handleErrorAndThenDisconnect <|
            Api.updatePassword
                (Session.viewerCredentials model.viewer)
                model.nextPassword
                pwd
                identity


updateUsername : Model -> (String -> Cmd Message)
updateUsername model =
    \pwd ->
        handleErrorAndThenDisconnect <|
            Api.updateUsername
                (Session.viewerCredentials model.viewer)
                model.nextUsername
                pwd
                identity


delete : Model -> String -> Cmd Message
delete model =
    \pwd ->
        handleErrorAndThenDisconnect <|
            Api.deleteAccount
                (Session.viewerCredentials model.viewer)
                pwd
                identity



-- VIEW


view : Model -> List (Html Message)
view model =
    case model.confirmation of
        Just ( password, command ) ->
            confirmation password command

        Nothing ->
            inputs model


confirmation : String -> (String -> Cmd Message) -> List (Html Message)
confirmation password command =
    [ Html.input
        [ Attribute.placeholder "Confirmation"
        , Attribute.value password
        , Event.onInput (WriteConfirmationPassword command)
        ]
        []
    , Html.button [ Event.onClick <| NowConfirm (command password) ] [ Html.text "Confirm" ]
    , Html.button [ Event.onClick <| GotError Cancellation ] [ Html.text "Cancel" ]
    ]


inputs : Model -> List (Html Message)
inputs model =
    [ Html.text "Error status is "
    , Html.text
        (case model.error of
            Just _ ->
                "True"

            Nothing ->
                "False"
        )
    , Html.input
        [ Attribute.placeholder "New username"
        , Attribute.value model.nextUsername
        , Event.onInput WriteNewUsername
        ]
        []
    , Html.button [ Event.onClick ClickUpdateUsername ] [ Html.text "Update username" ]
    , Html.input
        [ Attribute.placeholder "New password"
        , Attribute.value model.nextPassword
        , Event.onInput WriteNewPassword
        ]
        []
    , Html.button [ Event.onClick ClickUpdatePassword ] [ Html.text "Update password" ]
    , Html.button [ Event.onClick ClickDeleteAccount ] [ Html.text "Delete account" ]
    ]