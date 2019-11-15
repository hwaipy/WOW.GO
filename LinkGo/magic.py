def UIActionNormal():
    # Do nothing
    print('normal')
    pass


def UIActionLogin():
    # Exit and Reopen WOW
    print('login')
    # exitAndReopen(1)


def UIActionError():
    # Exit and Reopen WOW
    print('error')
    # exitAndReopen(2)


def UIActionQueue():
    # DO nothing
    print('queue')
    pass


def UIActionBegin():
    # Load game with the current character
    print('begin')
    # leftButtonClick(0.5, 0.2)
    # keyClick('\n')


def actionReopen():
    print('reopen')
    # openBattleNet()
    # delay(10)
    # keyClick('\n')
    # reactionDelay(30)


def exitAndReopen(escTimes):
    print('exit and reopen')
    # leftButtonClick(0.5, 0.2)
    # for i in range(escTimes):
    #     keyClickESC()
    # delay(1)
    # actionReopen()


debugSetUIStatus('NORMAL')
reactionDelay(15)
