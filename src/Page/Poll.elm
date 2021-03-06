module Page.Poll exposing
    ( Model, Message
    , update, view
    , initCreate, initDisplay, subscriptions
    )

{-| A page module that displays a Poll and calls sub-models to display questions, session and statistics


# TEA

@docs Model, Message
@docs update, view


# functions

@docs initCreate, initDisplay, subscriptions

-}

import Api.Polls exposing (PollDiscriminator, ServerPoll)
import Cmd.Extra exposing (withCmds, withNoCmd)
import Html exposing (Html, div, text)
import Html.Attributes exposing (class, placeholder, value)
import Html.Events exposing (onClick, onInput)
import Html.Events.Extra exposing (onEnterDown)
import Page.Poll.Session as Sessions
import Page.PollStatistics as Statistics
import Page.QuestionList as Questions
import Picasso.Button exposing (button, elevated)
import Picasso.Input as Input
import Route
import Session exposing (Viewer)
import Task
import Task.Extra
import Time



-- MODEL


type PollError
    = DisplayError
    | UpdateError
    | CreateError


type State
    = Creating
    | LoadingExisting
    | Editing ServerPoll Questions.Model Sessions.Model Statistics.Model
    | Ready ServerPoll Questions.Model Sessions.Model Statistics.Model


type alias Model =
    { viewer : Viewer
    , titleInput : String
    , state : State
    , error : Maybe PollError
    }


{-| Refreshes the page at a fixed interval given the current displaying state of the page, every 20 seconds in most cases
-}
subscriptions : Model -> Sub Message
subscriptions model =
    case model.state of
        Ready poll questionsModel sessionModel statisticsModel ->
            Sub.batch
                [ Sub.map SessionMessage (Sessions.subscriptions sessionModel)
                , Sub.map StatisticsMessage (Statistics.subscriptions statisticsModel)
                , Sub.map QuestionMessage (Questions.subscriptions questionsModel)
                , Time.every (1000 * 20) (always (LoadPoll poll.idPoll))
                ]

        Editing poll questionsModel sessionModel statisticsModel ->
            Sub.batch
                [ Sub.map SessionMessage (Sessions.subscriptions sessionModel)
                , Sub.map StatisticsMessage (Statistics.subscriptions statisticsModel)
                , Sub.map QuestionMessage (Questions.subscriptions questionsModel)
                , Time.every (1000 * 20) (always (LoadPoll poll.idPoll))
                ]

        _ ->
            Sub.none


{-| An init function to use when loading the page to create a new poll
-}
initCreate : Viewer -> ( Model, Cmd Message )
initCreate viewer =
    { viewer = viewer
    , titleInput = ""
    , state = Creating
    , error = Nothing
    }
        |> withNoCmd


{-| An init function to use when loading the page to display an existing poll
-}
initDisplay : Viewer -> PollDiscriminator -> ( Model, Cmd Message )
initDisplay viewer pollDiscriminator =
    { viewer = viewer
    , titleInput = ""
    , state = LoadingExisting
    , error = Nothing
    }
        |> withCmds
            [ Api.Polls.getPoll (Session.viewerCredentials viewer) pollDiscriminator GotNewPoll
                |> Task.mapError (always <| GotError DisplayError)
                |> Task.Extra.execute
            ]



-- UPDATE


type Message
    = WriteNewTitle String
    | ClickPollTitleButton
    | GotNewPoll ServerPoll
    | GotError PollError
    | RequestNavigateToPoll ServerPoll
    | LoadPoll PollDiscriminator
      -- Sub model
    | QuestionMessage Questions.Message
    | SessionMessage Sessions.Message
    | StatisticsMessage Statistics.Message


update : Message -> Model -> ( Model, Cmd Message )
update message model =
    case message of
        LoadPoll discriminator ->
            model
                |> withCmds
                    [ Api.Polls.getPoll
                        (Session.viewerCredentials model.viewer)
                        discriminator
                        GotNewPoll
                        |> Task.mapError (always <| GotError UpdateError)
                        |> Task.Extra.execute
                    ]

        SessionMessage subMessage ->
            case model.state of
                Ready poll pModel sModel iModel ->
                    let
                        ( updatedModel, cmd ) =
                            Sessions.update subMessage sModel
                    in
                    ( { model | state = Ready poll pModel updatedModel iModel }, Cmd.map SessionMessage cmd )

                _ ->
                    model |> withNoCmd

        QuestionMessage subMessage ->
            case model.state of
                Ready poll pollModel session iModel ->
                    let
                        ( updatedModel, cmd ) =
                            Questions.update subMessage pollModel
                    in
                    ( { model | state = Ready poll updatedModel session iModel }, Cmd.map QuestionMessage cmd )

                _ ->
                    model |> withNoCmd

        StatisticsMessage subMessage ->
            case model.state of
                Ready poll pModel sModel iModel ->
                    let
                        ( updatedModel, cmd ) =
                            Statistics.update subMessage iModel
                    in
                    ( { model | state = Ready poll pModel sModel updatedModel }, Cmd.map StatisticsMessage cmd )

                _ ->
                    model |> withNoCmd

        WriteNewTitle title ->
            { model | titleInput = title }
                |> withNoCmd

        ClickPollTitleButton ->
            case model.state of
                Creating ->
                    model
                        |> withCmds
                            [ Api.Polls.create
                                (Session.viewerCredentials model.viewer)
                                model.titleInput
                                RequestNavigateToPoll
                                |> Task.mapError (always <| GotError CreateError)
                                |> Task.Extra.execute
                            ]

                LoadingExisting ->
                    model |> withNoCmd

                Ready poll q s i ->
                    { model | state = Editing poll q s i }
                        |> withNoCmd

                Editing poll _ _ _ ->
                    { model | state = LoadingExisting }
                        |> withCmds
                            [ Api.Polls.update
                                (Session.viewerCredentials model.viewer)
                                poll.idPoll
                                model.titleInput
                                GotNewPoll
                                |> Task.mapError (always <| GotError UpdateError)
                                |> Task.Extra.execute
                            ]

        RequestNavigateToPoll poll ->
            model
                |> withCmds
                    [ Route.replaceUrl
                        (Session.viewerNavKey model.viewer)
                        (Route.DisplayPoll poll.idPoll)
                    ]

        GotError error ->
            { model | error = Just error } |> withNoCmd

        GotNewPoll poll ->
            let
                ( questionModel, questionCmd ) =
                    Questions.init model.viewer poll

                ( sessionModel, sessionCmd ) =
                    Sessions.init model.viewer poll.idPoll

                ( statisticsModel, statisticsCmd ) =
                    Statistics.init model.viewer poll

                updated =
                    case model.state of
                        Editing _ _ _ _ ->
                            { model | state = Editing poll questionModel sessionModel statisticsModel }

                        _ ->
                            { model | state = Ready poll questionModel sessionModel statisticsModel }
            in
            case model.state of
                Creating ->
                    updated
                        |> withCmds
                            [ Cmd.Extra.succeed <| RequestNavigateToPoll poll

                            -- We can safely dismiss other messages here.
                            ]

                LoadingExisting ->
                    { updated | titleInput = poll.title }
                        |> withCmds
                            [ Cmd.map QuestionMessage questionCmd
                            , Cmd.map SessionMessage sessionCmd
                            , Cmd.map StatisticsMessage statisticsCmd
                            ]

                Ready _ _ _ _ ->
                    { model | titleInput = poll.title }
                        |> withCmds
                            [ Cmd.map QuestionMessage Cmd.none
                            , Cmd.map SessionMessage Cmd.none
                            , Cmd.map StatisticsMessage Cmd.none
                            ]

                Editing _ _ _ _ ->
                    model
                        |> withCmds
                            [ Cmd.map QuestionMessage Cmd.none
                            , Cmd.map SessionMessage Cmd.none
                            , Cmd.map StatisticsMessage Cmd.none
                            ]



-- VIEW


view : Model -> List (Html Message)
view model =
    let
        editing =
            case model.state of
                Creating ->
                    True

                Editing _ _ _ _ ->
                    True

                _ ->
                    False

        textColor =
            if editing then
                "text-black font-semibold border-seaside-500"

            else
                "text-gray-500 font-semibold cursor-not-allowed border-dashed"
    in
    div
        [ class "align-middle mx-2 md:mx-8 mt-8"
        , class "bg-white shadow rounded-lg p-4"
        ]
        ([ Html.span
            [ class "block font-archivo capitalize text-black font-bold text-2xl" ]
            [ Html.text "Poll title :" ]
         , div [ class "flex flex-row items-center mt-2" ]
            [ Input.input
                [ onInput WriteNewTitle
                , onEnterDown ClickPollTitleButton
                , placeholder "What do unicorns dream of ? \u{1F984}"
                , Html.Attributes.autofocus True
                , value model.titleInput
                , class "w-full"
                , class "mr-4"
                , class textColor
                , Html.Attributes.readonly (not editing)
                ]
                []
            , buttonPollTitle model.state
            ]
         ]
            ++ prepended model
        )
        :: appended model


prepended : Model -> List (Html Message)
prepended model =
    case model.state of
        Ready _ _ sModel _ ->
            List.map (Html.map SessionMessage) (Sessions.moderatorView sModel)

        Editing _ _ sModel _ ->
            List.map (Html.map SessionMessage) (Sessions.moderatorView sModel)

        _ ->
            []


appended : Model -> List (Html Message)
appended model =
    case model.state of
        Ready _ qModel _ iModel ->
            List.map (Html.map QuestionMessage) (Questions.view qModel)
                ++ List.map (Html.map StatisticsMessage) (Statistics.view iModel)

        Editing _ qModel _ iModel ->
            List.map (Html.map QuestionMessage) (Questions.view qModel)
                ++ List.map (Html.map StatisticsMessage) (Statistics.view iModel)

        _ ->
            []


buttonPollTitle : State -> Html Message
buttonPollTitle state =
    let
        message =
            case state of
                Ready _ _ _ _ ->
                    "Edit"

                LoadingExisting ->
                    "Loading..."

                Creating ->
                    "Confirm"

                Editing _ _ _ _ ->
                    "Save"

        style =
            case state of
                Creating ->
                    Picasso.Button.filled ++ elevated

                LoadingExisting ->
                    Picasso.Button.filledDisabled ++ Picasso.Button.outlinedLight

                _ ->
                    Picasso.Button.filledLight ++ Picasso.Button.outlinedLight
    in
    button
        (style ++ [ onClick ClickPollTitleButton ])
        [ text message ]
