# region('center', 1, 4)
# sides = [i for i in range(0,10) if i !=5]
# for side in sides:
#     region('sides', -99+side*20, -96+side*20)
# region('sides', color(0.00, 0.400, 0.400))

# center = region('center')
# sides = region('sides')
# ratio = center / sides * 9
# title('Coincidence & HOMI')
# display('{}\n{}'.format(counts()[0], ratio))

# title('Ratio Display')
# display('5/9:   {}\n6/9:   {}'.format(str(counts()[4]/(counts()[8]+0.001))[:5], str(counts()[5]/(counts()[8]+0.001))[:5]))

def UIActionNormal():
    # Do nothing
    pass


def UIActionLogin():
    # Exit and Reopen WOW
    exitAndReopen(1)


def UIActionError():
    # Exit and Reopen WOW
    exitAndReopen(2)

def UIActionQueue():
    # DO nothing
    pass


def UIActionBegin():
    # Load game with the current character
    leftButtonClick(0.5, 0.2)
    keyClick('\n')


def exitAndReopen(escTimes):
    leftButtonClick(0.5, 0.2)
    for i in range(escTimes):
        keyClickESC()
    delay(1)
    openBattleNet()
    delay(1)
    keyClick('\n')
    delay(1)
