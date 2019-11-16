def UIActionNormal():
    print('normal')
    leftButtonClick(0.5, 0.2)
    keyClick('2', 'SHIFT')
    keyClick('2')
    delay(1.2)
    keyClick(' ')


    pass


def UIActionLogin():
    print('login')
    exitAndReopen(1)


def UIActionError():
    print('error')
    exitAndReopen(2)


def UIActionQueue():
    print('queue')
    pass


def UIActionBegin():
    print('begin')
    leftButtonClick(0.5, 0.2)
    keyClick('\n')


def actionReopen():
    print('reopen')
    openBattleNet()
    delay(10)
    keyClick('\n')
    reactionDelay(30)


def exitAndReopen(escTimes):
    leftButtonClick(0.5, 0.2)
    for i in range(escTimes):
        keyClickESC()
    delay(5)
    actionReopen()


# debugSetUIStatus('NORMAL')
reactionDelay(15)
