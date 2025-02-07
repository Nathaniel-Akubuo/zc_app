import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hng/app/app.locator.dart';
import 'package:hng/app/app.router.dart';
import 'package:hng/models/channel_members.dart';
import 'package:hng/models/channel_model.dart';
import 'package:hng/models/user_post.dart';
import 'package:hng/package/base/server-request/channels/channels_api_service.dart';
import 'package:hng/services/centrifuge_service.dart';
import 'package:hng/services/local_storage_services.dart';
import 'package:hng/services/notification_service.dart';

import 'package:hng/utilities/enums.dart';
import 'package:hng/utilities/storage_keys.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class ChannelPageViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _channelsApiService = locator<ChannelsApiService>();
  final storage = locator<SharedPreferenceLocalStorage>();
  final _centrifugeService = locator<CentrifugeService>();
  final _notificationService = locator<NotificationService>();

  final _bottomSheetService = locator<BottomSheetService>();
  final _snackbarService = locator<SnackbarService>();

  // ignore: todo
  //TODO refactor this
  ScrollController scrollController = ScrollController();
  bool isExpanded = false;
  bool isVisible = false;
  bool isLoading = true;

  List<ChannelMembermodel> channelMembers = [];
  List<UserPost>? channelUserMessages = [];
  StreamSubscription? messageSubscription;
  StreamSubscription? notificationSubscription;
  String channelID = '';

  void onMessageFieldTap() {
    isVisible = true;
    notifyListeners();
  }

  void initialise(String channelId) async {
    channelID = channelId;
    await joinChannel(channelId);
    fetchMessages(channelId);
    // getChannelSocketId("$channelId");
    fetchChannelMembers(channelId);
    listenToNewMessage(channelId);
    // listenToNewMessages("$channelId");
  }

  void showThreadOptions() async {
    await _bottomSheetService.showCustomSheet(
      variant: BottomSheetType.threadOptions,
      isScrollControlled: true,
    );
  }

  void onMessageFocusChanged() {
    isVisible = false;
    notifyListeners();
  }

  Future joinChannel(String channelId) async {
    await _channelsApiService.joinChannel(channelId);
  }

  void getChannelSocketId(String channelId) async {
    final channelSockId =
        await _channelsApiService.getChannelSocketId(channelId);

    websocketConnect(channelSockId);
  }

  void fetchChannelMembers(String channelId) async {
    channelMembers =
        await _channelsApiService.getChannelMembers(channelId) ?? [];
    notifyListeners();
  }

  void fetchMessages(String channelId) async {
    List? channelMessages =
        await _channelsApiService.getChannelMessages(channelId);
    channelUserMessages = [];

    channelMessages.forEach((data) async {
      String userid = data["user_id"];

      channelUserMessages?.add(
        UserPost(
            id: data['_id'],
            displayName: userid,
            statusIcon: '7️⃣',
            lastSeen: '4 hours ago',
            message: data['content'],
            channelType: ChannelType.public,
            postEmojis: <PostEmojis>[],
            userThreadPosts: <UserThreadPost>[],
            channelName: channelId,
            userImage: 'assets/images/chimamanda.png',
            userID: userid,
            channelId: channelId),
      );
    });
    isLoading = false;
    notifyListeners();
  }

  void sendMessage(
    String message,
  ) async {
    String? userId = storage.getString(StorageKeys.currentUserId);
    await _channelsApiService.sendChannelMessages(
        channelID, "$userId", message);
    scrollController.jumpTo(scrollController.position.minScrollExtent);
    notifyListeners();
  }

  void exitPage() {
    _navigationService.back();
  }

  String time() {
    return "${DateTime.now().hour.toString()}:${DateTime.now().minute.toString()}";
  }

  Future? navigateToChannelInfoScreen(
      int numberOfMembers, ChannelModel channelDetail) async {
    await NavigationService().navigateTo(Routes.channelInfoView,
        arguments: ChannelInfoViewArguments(
            numberOfMembers: numberOfMembers,
            channelMembers: channelMembers,
            channelDetail: channelDetail));
  }

  Future? navigateToAddPeople(String channelName, String channelId) async {
    await _navigationService.navigateTo(Routes.channelAddPeopleView,
        arguments: ChannelAddPeopleViewArguments(
            channelId: channelId, channelName: channelName));
    _snackbarService.showCustomSnackBar(
        duration: const Duration(milliseconds: 2048),
        message: "Members were added successfully",
        variant: SnackbarType.success);
    fetchChannelMembers(channelId);
  }

  void goBack() => _navigationService.back();

  navigateToChannelEdit(String channelName, String channelId) {
    _navigationService.navigateTo(Routes.editChannelPageView,
        arguments: EditChannelPageViewArguments(
          channelName: channelName,
          channelId: channelId,
        ));
  }

  void websocketConnect(String channelSocketId) async {
    await _centrifugeService.subscribe(channelSocketId);
  }

  void listenToNewMessage(String channelId) async {
    String channelSockId =
        await _channelsApiService.getChannelSocketId(channelId);

    messageSubscription = _centrifugeService.listen(
      socketId: channelSockId,
      channelId: channelId,
      onData: (message) {
        fetchMessages(channelId);
        notifyListeners();
      },
    );
  }

  void showNotificationForOtherChannels(
      String channelId, String channelName) async {
    notificationSubscription = _centrifugeService.onNotificationReceived(
      channelId: channelId,
      onData: (message) {
        _notificationService.show(
          title: '#$channelName',
          body: message['content'],
          payload: NotificationPayload(
            messageId: message['_id'],
            roomId: message['channel_id'],
            name: channelName,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    // this fixes the scroll controller error
    messageSubscription?.cancel();
    notificationSubscription?.cancel();
    super.dispose();
  }

  void toggleExpanded() {
    isExpanded = !isExpanded;
    notifyListeners();
  }
}
