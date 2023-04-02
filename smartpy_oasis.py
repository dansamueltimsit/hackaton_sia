# Store Value - Example for illustrative purposes only.

import smartpy as sp
import random as rd


class oasis(sp.Contract):
    def __init__(self, adress_organizer):
        self.init(organizer=adress_organizer, \
                  map_players=sp.map(), \
                  map_game_dev=sp.map(), nbr_players=0, \
                  status="none")

        # can be none, playing and finish

    # @sp.private_lambda
    # def compute_key(name_player, previous_proof, key):
    #   return 1 #sp.return(1)

    @sp.entry_point
    def begin_tourney(self):
        status = "playing"

    @sp.entry_point
    def add_dev(self):
        sp.verify(~self.data.map_game_dev.contains(sp.sender), "You have already created an account")
        self.data.map_game_dev[sp.sender] = 1

    @sp.entry_point
    def add_player(self):
        sp.verify(~self.data.map_players.contains(sp.sender), "You have already created an account")
        self.data.map_players[sp.sender] = sp.record(list_keys=[1], status="playing")
        self.data.nbr_players += 1

    @sp.entry_point
    def delete_player(self):
        sp.verify(self.data.map_players.contains(sp.sender), "You have do not have an account")
        del self.data.map_players[sp.sender]
        self.data.nbr_players -= 1

    @sp.private_lambda
    def compute_key(self, winner, previous_key, private_key):
        sp.result(1)

    @sp.entry_point
    def claim_victory_game(self, param):
        winner = param.winner
        private_key = param.private_key
        sp.verify(self.data.map_game_dev.contains(sp.sender), "You are not a game dev")

        sp.verify(self.data.map_players.contains(winner), "Player does not exist")

        with sp.if_(self.data.map_players[winner].status == "playing"):
            self.data.map_players[winner].list_keys.push(
                1)  # self.compute_key(winner, self.data.map_players[sp.sender].list_keys[-1], private_key))

    @sp.entry_point
    def claim_loss_game(self, params):
        loser = params.loser
        sp.verify(self.data.map_players.contains(loser), "Player does not exist")
        with sp.if_(self.data.map_players[loser].status == "playing"):
            self.data.map_players[loser].status = "lost"

    @sp.entry_point
    def claim_victory(self):
        sp.verify(self.data.map_players.contains(sp.sender), "You have do not have an account")
        with sp.if_(sp.len(self.data.map_players[sp.sender].list_keys) == sp.len(self.data.map_game_dev)):
            self.data.status = "finished"
            sp.result(sp.unit)


if "templates" not in __name__:
    organizer = sp.test_account('organizer')

    nbr_players = 1
    nbr_games = 3

    list_players = [sp.test_account('tz2_player' + str(i)) for i in range(nbr_players)]
    list_player_address = [sp.address('tz2_player' + str(i)) for i in range(nbr_players)]
    list_game_dev = [sp.test_account("tz1_dev" + str(i)) for i in range(nbr_games)]
    list_game_dev_address = [sp.address("tz1_dev" + str(i)) for i in range(nbr_games)]


    @sp.add_test(name="oasis_project")
    def test():
        c1 = oasis(organizer.address)
        scenario = sp.test_scenario()
        scenario.h1("oasis_project")
        scenario += c1
        for j in range(nbr_games):
            c1.add_dev().run(sender=list_game_dev[j])

        for i in range(nbr_players):
            c1.add_player().run(sender=list_players[i])

        c1.begin_tourney()
        for j in range(nbr_games):
            for i in range(nbr_players):
                if rd.random() < 0.8:
                    c1.claim_victory_game(winner=list_players[i].address, private_key=1).run(sender=list_game_dev[j])
                else:
                    c1.claim_loss_game(loser=list_players[i].address).run(sender=list_game_dev[j])
        for i in range(nbr_players):
            if c1.claim_victory().run(sender=list_players[i]):
                print(str(i) + " has won all games")


    sp.add_compilation_target("oasis", oasis(sp.address('tz1_organizer_adress')))
