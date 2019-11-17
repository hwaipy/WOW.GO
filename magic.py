def UIActionNormal():
    print('normal')
    leftButtonClick(0.5, 0.2)
    keyClick('2', 'SHIFT')
    keyClick(']')
    # keyClick('2')
    # delay(1.2)
    # keyClick(' ')

    import time
    status = 'Prepare'
    keyClick('2')
    delay(2)
    ysP = []
    ysW = []
    fishBoundsXOffset = 0.5
    fishBoundsYOffset = 0.6
    fishBoundsWidth = 0.3
    fishBoundsHeight = 0.2
    waitingStart = time.time()
    while True:
        if status == 'Prepare':
            if time.time() - waitingStart > 2:
                status = 'Waiting'
            else:
                ysP.append(fishCapture(fishBoundsXOffset, fishBoundsYOffset, fishBoundsWidth, fishBoundsHeight)[1])
        elif status == 'Waiting':
            if time.time() - waitingStart > 25:
                break
            else:
                ysW.append(fishCapture(fishBoundsXOffset, fishBoundsYOffset, fishBoundsWidth, fishBoundsHeight)[1])
                if (len(ysP) > 0) and (len(ysW) > 0):
                    if (max(ysW) - min(ysW)) > 2 * (max(ysP) - min(ysP)):
                        print("done. ending")
                        delay(0.8, 1.6)
                        position = fishCapture(fishBoundsXOffset, fishBoundsYOffset, fishBoundsWidth, fishBoundsHeight)
                        print(position)
                        print(position[0] + fishBoundsXOffset - fishBoundsWidth / 2)
                        print(position[1] + fishBoundsYOffset - fishBoundsHeight / 2)
                        rightButtonClick(position[0] + fishBoundsXOffset - fishBoundsWidth / 2,
                                         position[1] + fishBoundsYOffset - fishBoundsHeight / 2)
                        delay(1, 2)
                        if random() < 0.05:
                            keyClick('1')
                            delay(1.5, 1.8)
                        print('eat')
                        keyClick(' ')
                        break
        else:
            print('wrong!!!')
            break
    reactionDelay(3)


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


def test():
    center = fishCapture(0.5, 0.6, 0.3, 0.2)
    print(center)


# debugSetUIStatus('NORMAL')
reactionDelay(15)
