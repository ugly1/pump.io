# pump/router.js
#
# Backbone router for the pump.io client UI
#
# Copyright 2011-2012, E14N https://e14n.com/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
((_, $, Backbone, Pump) ->
  Pump.Router = Backbone.Router.extend(
    routes:
      "": "home"
      ":nickname": "profile"
      ":nickname/favorites": "favorites"
      ":nickname/following": "following"
      ":nickname/followers": "followers"
      ":nickname/activity/:id": "activity"
      ":nickname/lists": "lists"
      ":nickname/list/:uuid": "list"
      ":nickname/activity/:uuid": "activity"
      ":nickname/:type/:uuid": "object"
      "main/messages": "messages"
      "main/settings": "settings"
      "main/account": "account"
      "main/register": "register"
      "main/login": "login"
      "main/remote": "remote"
      "main/recover": "recover"
      "main/recover-sent": "recoverSent"
      "main/recover/:code": "recoverCode"

    register: ->
      Pump.body.startLoad()
      Pump.body.setContent
        contentView: Pump.RegisterContent
        title: "Register"
      , ->
        Pump.body.endLoad()
        return

      return

    login: ->
      continueTo = Pump.getContinueTo()
      if Pump.principalUser
        Pump.router.navigate continueTo, true
        Pump.clearContinueTo()
      else if Pump.principal
        Pump.router.navigate continueTo, true
        Pump.clearContinueTo()
      else
        Pump.body.startLoad()
        Pump.body.setContent
          contentView: Pump.LoginContent
          title: "Login"
        , ->
          Pump.body.endLoad()
          return

      return

    remote: ->
      Pump.body.startLoad()
      Pump.body.setContent
        contentView: Pump.RemoteContent
        title: "Remote login"
      , ->
        Pump.body.endLoad()
        return

      return

    recover: ->
      Pump.body.startLoad()
      Pump.body.setContent
        contentView: Pump.RecoverContent
        title: "Recover your password"
      , ->
        Pump.body.endLoad()
        return

      return

    recoverSent: ->
      Pump.body.startLoad()
      Pump.body.setContent
        contentView: Pump.RecoverSentContent
        title: "Recovery email sent"
      , ->
        Pump.body.endLoad()
        return

      return

    recoverCode: (code) ->
      Pump.body.startLoad()
      Pump.body.setContent
        contentView: Pump.RecoverCodeContent
        title: "Recovery code"
      , ->
        Pump.body.endLoad()
        return

      return

    settings: ->
      Pump.body.startLoad()
      Pump.body.setContent
        contentView: Pump.SettingsContent
        model: Pump.principal
        title: "Settings"
      , ->
        Pump.body.endLoad()
        return

      return

    account: ->
      Pump.body.startLoad()
      Pump.body.setContent
        contentView: Pump.AccountContent
        model: Pump.principalUser
        title: "Account"
      , ->
        Pump.body.endLoad()
        return

      return

    messages: ->
      user = Pump.principalUser
      major = user.majorDirectInbox
      minor = user.minorDirectInbox
      Pump.body.startLoad()
      Pump.fetchObjects [
        user
        major
        minor
      ], (err, objs) ->
        if err
          Pump.error err
          return
        Pump.body.setContent
          contentView: Pump.MessagesContent
          data:
            major: major
            minor: minor
            headless: false

          title: "Messages"
        , ->
          Pump.body.endLoad()
          return

        return

      return

    home: ->
      pair = Pump.getUserCred()
      Pump.body.startLoad()
      if pair
        user = Pump.principalUser
        major = user.majorInbox
        minor = user.minorInbox
        Pump.fetchObjects [
          user
          major
          minor
        ], (err, objs) ->
          if err
            Pump.error err
            return
          Pump.body.setContent
            contentView: Pump.InboxContent
            data:
              major: major
              minor: minor
              headless: false

            title: "Home"
          , ->
            Pump.body.endLoad()
            return

          return

      else
        Pump.body.setContent
          contentView: Pump.MainContent
          title: "Welcome"
        , ->
          Pump.body.endLoad()
          return

      return

    profile: (nickname) ->
      router = this
      user = Pump.User.unique(nickname: nickname)
      major = user.majorStream
      minor = user.minorStream
      Pump.body.startLoad()
      Pump.fetchObjects [
        user
        major
        minor
      ], (err, objs) ->
        profile = user.profile
        if err
          Pump.error err
          return
        Pump.body.setContent
          contentView: Pump.UserPageContent
          userContentView: Pump.ActivitiesUserContent
          title: profile.get("displayName")
          data:
            major: major
            minor: minor
            headless: true
            profile: profile
        , ->
          Pump.body.endLoad()
          return

        return

      return

    favorites: (nickname) ->
      router = this
      user = Pump.User.unique(nickname: nickname)
      favorites = Pump.ActivityObjectStream.unique(url: Pump.fullURL("/api/user/" + nickname + "/favorites"))
      Pump.body.startLoad()
      Pump.fetchObjects [
        user
        favorites
      ], (err, objs) ->
        profile = user.profile
        if err
          Pump.error err
          return
        Pump.body.setContent
          contentView: Pump.FavoritesContent
          userContentView: Pump.FavoritesUserContent
          userContentStream: favorites
          title: nickname + " favorites"
          data:
            favorites: favorites
            profile: profile
        , ->
          Pump.body.endLoad()
          return

        return

      return

    followers: (nickname) ->
      router = this
      user = Pump.User.unique(nickname: nickname)
      followers = Pump.PeopleStream.unique(url: Pump.fullURL("/api/user/" + nickname + "/followers"))
      Pump.body.startLoad()
      Pump.fetchObjects [
        user
        followers
      ], (err, objs) ->
        profile = user.profile
        if err
          Pump.error err
          return
        Pump.body.setContent
          contentView: Pump.FollowersContent
          userContentView: Pump.FollowersUserContent
          userContentStream: followers
          title: nickname + " followers"
          data:
            followers: followers
            profile: profile
        , ->
          Pump.body.endLoad()
          return

        return

      return

    following: (nickname) ->
      router = this
      user = Pump.User.unique(nickname: nickname)
      following = Pump.PeopleStream.unique(url: Pump.fullURL("/api/user/" + nickname + "/following"))
      
      # XXX: parallelize this?
      Pump.body.startLoad()
      Pump.fetchObjects [
        user
        following
      ], (err, objs) ->
        profile = user.profile
        if err
          Pump.error err
          return
        Pump.body.setContent
          contentView: Pump.FollowingContent
          userContentView: Pump.FollowingUserContent
          userContentStream: following
          title: nickname + " following"
          data:
            following: following
            profile: profile
        , ->
          Pump.body.endLoad()
          return

        return

      return

    lists: (nickname) ->
      router = this
      user = Pump.User.unique(nickname: nickname)
      lists = Pump.ListStream.unique(url: Pump.fullURL("/api/user/" + nickname + "/lists/person"))
      Pump.body.startLoad()
      Pump.fetchObjects [
        user
        lists
      ], (err, objs) ->
        profile = user.profile
        if err
          Pump.error err
          return
        Pump.body.setContent
          contentView: Pump.ListsContent
          userContentView: Pump.ListsUserContent
          listContentView: Pump.ListsListContent
          title: nickname + " lists"
          data:
            lists: lists
            list: null
            profile: profile
        , ->
          Pump.body.endLoad()
          return

        return

      return

    list: (nickname, uuid) ->
      router = this
      user = Pump.User.unique(nickname: nickname)
      lists = Pump.ListStream.unique(url: Pump.fullURL("/api/user/" + nickname + "/lists/person"))
      list = Pump.List.unique(links:
        self:
          href: "/api/collection/" + uuid
      )
      members = Pump.PeopleStream.unique(url: Pump.fullURL("/api/collection/" + uuid + "/members"))
      Pump.body.startLoad()
      Pump.fetchObjects [
        user
        lists
        list
        members
      ], (err, objs) ->
        if err
          Pump.error err
          return
        profile = user.profile
        options =
          contentView: Pump.ListContent
          userContentView: Pump.ListUserContent
          listContentView: Pump.ListListContent
          title: nickname + " - list -" + list.get("displayName")
          listContentModel: list
          data:
            lists: lists
            list: list
            profile: profile
            members: members

        if err
          Pump.error err
          return
        Pump.body.setContent options, (view) ->
          lm = Pump.body.content.userContent.listMenu
          lm.$(".active").removeClass "active"
          lm.$("li[data-list-id='" + list.id + "']").addClass "active"
          Pump.body.endLoad()
          return

        return

      return

    object: (nickname, type, uuid) ->
      router = this
      user = Pump.User.unique(nickname: nickname)
      obj = Pump.ActivityObject.unique(
        uuid: uuid
        objectType: type
        userNickname: nickname
      )
      Pump.body.startLoad()
      Pump.fetchObjects [
        user
        obj
      ], (err, objs) ->
        if err
          Pump.error err
          return
        Pump.body.setContent
          contentView: Pump.ObjectContent
          model: obj
          title: obj.get("displayName") or (obj.get("objectType") + " by " + nickname)
        , ->
          Pump.body.endLoad()
          return

        return

      return

    activity: (nickname, uuid) ->
      router = this
      user = Pump.User.unique(nickname: nickname)
      activity = Pump.Activity.unique(uuid: uuid)
      Pump.body.startLoad()
      Pump.fetchObjects [
        user
        activity
      ], (err, objs) ->
        if err
          Pump.error err
          return
        Pump.body.setContent
          contentView: Pump.ActivityContent
          model: activity
          title: activity.content
        , ->
          Pump.body.endLoad()
          return

        return

      return
  )
  return
) window._, window.$, window.Backbone, window.Pump
