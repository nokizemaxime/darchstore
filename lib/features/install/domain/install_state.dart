sealed class InstallState {
  const InstallState();
}

class InstallIdle extends InstallState {
  const InstallIdle();
}

class InstallNeedsPermission extends InstallState {
  const InstallNeedsPermission();
}

class InstallDownloading extends InstallState {
  const InstallDownloading(this.progress);

  final double? progress;
}

class InstallVerifying extends InstallState {
  const InstallVerifying();
}

class InstallAwaitingUser extends InstallState {
  const InstallAwaitingUser();
}

class InstallSuccess extends InstallState {
  const InstallSuccess();
}

class InstallFailure extends InstallState {
  const InstallFailure(this.message);

  final String message;
}

extension InstallStateBusy on InstallState {
  bool get isBusy {
    return this is InstallDownloading ||
        this is InstallVerifying ||
        this is InstallAwaitingUser;
  }
}
