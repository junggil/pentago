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
    if not games[room]?
        games[room] = {}
        games[room]['round'] = 0
        games[room]['win'] = []
        games[room]['color'] = []
        games[room]['turn'] = []
    else
        games[room]['round'] += 1
    games[room]['board'] =
        A : ["empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty"],
        B : ["empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty"],
        C : ["empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty"],
        D : ["empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty"]
    games[room]['play_cnt'] = 0
    games[room]['finish'] = false
    games[room]['success'] = true
    games[room]['turn'][0] = 0
    games[room]['turn'][1] = "not started"
    games[room]['turn'][2] = "not started"
    games[room]['turn'][3] = "not started"


check_win = (board) ->
    patterns =
        horizontal : [0,1,2,9,10],
        vertical   : [0,3,6,18,21],
        diagonal   : [0,4,8,30,34],
        anti_diag  : [0,-2,-4,-9,-11]
    positions =
        horizontal : [0,1,3,4,6,7,18,19,21,22,24,25],
        vertical   : [0,1,2,3,4,5,9,10,11,12,13,14],
        diagonal   : [0,1,3,4,],
        anti_diag  : [21,22,24,25]

    _board = board['A'].concat(board['B'], board['C'], board['D'])
    
    for color in ['white', 'black']
        for i of patterns
            pattern  = patterns[i]
            position = positions[i]
            for pos in position
                if (color for _ in [0...5]).join('') == (_board[pos+i] for i in pattern).join('')
                    return color
    for marble in _board
        if marble == 'empty'
            return 'NotEnd'
    return 'Draw'

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

    if game?
        if nick in game['color']
            res.json({success:true, finish:game['finish'], \
                turn:game['nextturn'] == nick , \
                board:game['board'], \
                round:game['round'], \
                wins:if game['win'][0] == nick then game['win'][1] else game['win'][3],
                color:if game['color'][game['round'] % 2] == nick then "white" else "black"\
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
    game['turn'][0] = game['play_cnt']
    game['turn'][1] = nick
    game['turn'][2] = target
    game['turn'][3] = direction
    game['nextturn'] = game['color'][idx^1]

    w_result = check_win(game['board'])
   
    if w_result != "NotEnd"
        if w_result == "white"
            game['win'][1] += 1
        else
            game['win'][3] += 1

        if (game['round'] + 1) < 10
            game['nextturn'] = 'hold on displaying result'

            setTimeout ( ->
                new_game(room)
                game['nextturn'] = game['color'][game['round'] % 2]
            ), 5000

            res.json({success:true, msg:"move on to the next game"})
            return
        else
            game['finish'] = true
            game['nextturn'] = "game is over"
            res.json({success:true, msg:"game is over"})
            return

    else
        res.json({success:true})
        return

app.get '/', (req, res) ->
    res.render('index.html')

app.listen process.env.PORT || 5000 , () =>
  console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env
