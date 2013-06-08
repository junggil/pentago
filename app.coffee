express = require 'express'

app = express.createServer()
app.configure =>
  app.set 'views', __dirname + '/views'
  app.set 'view options', {layout:false}
  app.register '.html', {compile: (str, options) -> return (locals) -> return str}
  app.set 'jsonp callback', true
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use app.router
  app.use express.static(__dirname + '/public')

app.configure 'development', () =>
  app.use express.errorHandler({ dumpExceptions: true, showStack: true })

app.configure 'production', () =>
  app.use express.errorHandler()

games = {}

new_game = (room) ->
    games[room] = {}
    games[room]['round'] = 0
    games[room]['win'] = []
    games[room]['color'] = []
    games[room]['turn'] = []
    games[room]['board'] =
        A : ["empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty"]
        B : ["empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty"]
        C : ["empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty"]
        D : ["empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty"]
    games[room]['round'] += 1
    games[room]['play_cnt'] = 0
    games[room]['finish'] = false
    games[room]['success'] = true
    games[room]['turn'] = []
    games[room]['turn'][0] = 0
    games[room]['turn'][1] = "not started"
    games[room]['turn'][2] = "not started"
    games[room]['turn'][3] = "not started"


check_win = (board, marble_color) ->

    candidate = [0..18]
    candidate[0] = [board['A'][0], board['A'][3], board['A'][6], board['C'][0], board['C'][3], board['C'][6] ]
    candidate[1] = [board['A'][1], board['A'][4], board['A'][7], board['C'][1], board['C'][4], board['C'][7] ]
    candidate[2] = [board['A'][2], board['A'][5], board['A'][8], board['C'][2], board['C'][5], board['C'][8] ]

    candidate[3] = [board['B'][0], board['B'][3], board['B'][6], board['D'][0], board['D'][3], board['D'][6] ]
    candidate[4] = [board['B'][1], board['B'][4], board['B'][7], board['D'][1], board['D'][4], board['D'][7] ]
    candidate[5] = [board['B'][2], board['B'][5], board['B'][8], board['D'][2], board['D'][5], board['D'][6] ]


    candidate[6] = [board['A'][0], board['A'][4], board['A'][8], board['D'][0], board['D'][4], board['D'][8] ]
    candidate[7] = [board['B'][2], board['B'][4], board['B'][6], board['C'][2], board['C'][4], board['C'][6] ]


    candidate[8] = [board['A'][0], board['A'][1], board['A'][2], board['B'][0], board['B'][1], board['B'][2] ]
    candidate[9] = [board['A'][3], board['A'][4], board['A'][5], board['B'][3], board['B'][4], board['B'][5] ]
    candidate[10] = [board['A'][6], board['A'][7], board['A'][8], board['B'][6], board['B'][7], board['B'][8] ]

    candidate[11] = [board['C'][0], board['C'][1], board['C'][2], board['D'][0], board['D'][1], board['D'][2] ]
    candidate[12] = [board['C'][3], board['C'][4], board['C'][5], board['D'][3], board['D'][4], board['D'][5] ]
    candidate[13] = [board['C'][6], board['C'][7], board['C'][8], board['D'][6], board['D'][7], board['D'][8] ]

    candidate[14] = [board['A'][1], board['A'][5], board['B'][6], board['D'][1], board['D'][5], "empty" ]
    candidate[15] = [board['A'][3], board['A'][7], board['C'][2], board['D'][3], board['D'][7], "empty" ]
    candidate[16] = [board['B'][1], board['B'][3], board['A'][8], board['C'][1], board['C'][3], "empty" ]
    candidate[17] = [board['B'][5], board['B'][7], board['D'][0], board['C'][5], board['C'][7], "empty" ]


    for i in [0..18]
        check_list = candidate[i]
        ret = searchforwin(check_list, marble_color)
        if ret
            msg = marble_color

    if msg != marble_color
        for i in ['A','B','C','D']
            if "empty" in board[i]
                msg = "NotEnd"
                break

        if msg != "NotEnd"
            msg = "draw"

    return msg


searchforwin = (check_list, marble_color) ->
    cnt = 0

    for i in [0..5]
        if marble_color == check_list[i] then cnt +=1

    if cnt == 6
        return true
    else if cnt == 5
        if check_list[0] != marble_color || check_list[5] != marble_color
            return true
        else
            return false
    else
        return false

rotate = (old_board, direction) ->
    if direction == 'L'
        return (old_board[i] for i in [2,5,8,1,4,7,0,3,6])
    else
        return (old_board[i] for i in [6,3,0,7,4,1,8,5,2])

app.get '/:room/register/:id', (req, res) =>
    res.header("Access-Control-Allow-Origin", "*")
    
    room = req.params.room
    nick = req.params.id
    
    if not games[room]?
        new_game(room)

    game = games[room]

    if game['finish']
        res.json({success:false, msg:"the game is over, please init the room"})
    else
        if game['color'].length < 2
            if nick in game['color']
                res.json({success:false, msg:'player name is already taken'})
            else
                game['color'].push nick
                game['win'].push nick
                game['win'].push 0
                
                if game['color'].length == 2
                    game['nextturn'] = game['color'][0]

                res.json({success:true, msg:'welcome'})
        else
            res.json({success:false, msg:'players are full'})

app.get '/:room', (req, res) =>
    res.header("Access-Control-Allow-Origin", "*")

    room = req.params.room
    if not games[room]?
        new_game(room)
    res.json(games[room])

app.get '/:room/init', (req, res) =>
    room = req.params.room
    new_game(room)
    res.json(games[room])

app.get '/:room/get/:id', (req, res) =>
    res.header("Access-Control-Allow-Origin", "*")

    room = req.params.room
    nick = req.params.id
    game = games[room]

    if game? and game['finish'] == false
        if nick in game['color']
            res.json({success:true, finish:game['finish'], \
                turn:game['nextturn'] == nick , \
                board:game['board'], \
                round:game['round'], \
                wins:if game['win'][0] == nick then game['win'][1] else game['win'][3],
                color:if game['color'][0] == nick then "white" else "black"\
                })
        else
            res.json({success:false, msg:'player name is not valid'})
    else
        res.json({success:false, msg:'game room is not valid'})

app.get '/:room/play/:id/:target/:turn', (req, res) =>
    res.header("Access-Control-Allow-Origin", "*")
    
    room = req.params.room
    nick = req.params.id
    target = req.params.target
    direction = req.params.turn

    if not games[room]?
        new_game(room)

    game = games[room]

    if game['finish']
        res.json({success:false, msg:"the game is over, please init the room"})
        return
    if nick not in game['color']
        res.json({success:false, msg:'player name is not valid'})
        return
    if game['nextturn'] != nick
        res.json({success:false, msg:'it is not your turn'})
        return
    if game['board'][target[0]][target[1]] != "empty"
        res.json({success:false, msg:'the target place you picked is occupied, please pick another target place'})
        return

    marble = if game['color'][0] == nick then "white" else "black"
    idx    = if game['color'][0] == nick then 0 else 1

    game['play_cnt'] += 1
    game['board'][target[0]][target[1]] = marble
    game['board'][direction[0]] = rotate(game['board'][direction[0]], direction[1])
    console.log(game['board'][direction[0]])
    console.log(direction[1])
    game['turn'][0] = game['play_cnt']
    game['turn'][1] = nick
    game['turn'][2] = target
    game['turn'][3] = direction
    game['nextturn'] = game['color'][idx^1]

    w_result = check_win(game['board'], marble)
    console.log(w_result)
   
    if w_result != "NotEnd"
        if w_result == "white"
            game['win'][1] += 1
        else
            game['win'][3] += 1

        if game['round'] > 10
            game['finish'] = true
            game['nextturn'] = ""
            res.json({success:true, msg:"game is over, turn:false"})
            return
        else
            res.json({success:true, msg:"move on to the next game"})

            setTimeout ( ->
                new_game(room)
                game['color'] = (game['color'][i] for i in [1..0])
                game['nextturn'] = game['color'][0]
            ), 5000

app.get '/', (req, res) ->
    res.render('index.html')

app.listen process.env.PORT || 5000 , () =>
  console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env
