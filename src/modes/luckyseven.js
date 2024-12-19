/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS202: Simplify dynamic range loops
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
import * as cardutils from '../cardutils';

const MANEUVER = "Maneuver";
const ATTACK = "Attack";

const WON = "You Win!";
const LOST = "You Lost!";

const mode = {
  name: "Lucky Seven",
  help: `\
| GOAL:

To be written

| PLAY:

To be written

| HARD MODE:

To be implemented
\
`,

  placeSquad(squad, xPos, yPos) {
    return (() => {
      const result = [];
      for (let squadIndex = 0, end = squad.length, asc = 0 <= end; asc ? squadIndex < end : squadIndex > end; asc ? squadIndex++ : squadIndex--) {
        var cards, posIndex, v;
        var s = squad[squadIndex];
        var squadPos = squadIndex + 1;
        for (posIndex = 0; posIndex < xPos.length; posIndex++) {
          cards = xPos[posIndex];
          for (v of Array.from(cards)) {
            if (v === squadPos) {
              s.x = posIndex;
            }
          }
        }
        result.push((() => {
          const result1 = [];
          for (posIndex = 0; posIndex < yPos.length; posIndex++) {
            cards = yPos[posIndex];
            result1.push((() => {
              const result2 = [];
              for (v of Array.from(cards)) {
                if (v === squadPos) {
                  result2.push(s.y = posIndex);
                } else {
                  result2.push(undefined);
                }
              }
              return result2;
            })());
          }
          return result1;
        })());
      }
      return result;
    })();
  },

  newGame() {
    this.state = {
      hard: this.hard,
      draw: {
        pos: 'none',
        cards: []
      },
      selection: {
        type: 'none',
        outerIndex: 0,
        innerIndex: 0
      },
      pile: {
        show: 0,
        cards: []
      },
      foundations: [],
      work: [],
      grid: [],
      log: [],
      lastRound: false,
      phase: MANEUVER
    };

    const xPos = [
      [1,6],
      [2],
      [3,7],
      [4],
      [5,8],
      []
    ];
    const yPos = [
      [1,2],
      [3,4],
      [5,6],
      [7,8]
    ];

    this.luckyLog("Dealing new game...");

    const squad = [
      { raw: cardutils.ANVIL },
      { raw: cardutils.ATHLETE },
      { raw: cardutils.HAMMER },
      { raw: cardutils.JOKER },
      { raw: cardutils.LEADER },
      { raw: cardutils.NATURAL },
      { raw: cardutils.PACIFIST },
      { raw: cardutils.MOUSE }
    ];
    cardutils.shuffle(xPos);
    cardutils.shuffle(yPos);
    cardutils.shuffle(squad);
    this.placeSquad(squad, xPos, yPos);
    console.log(squad);

    for (let colIndex = 0; colIndex < 6; colIndex++) {
      var row = [];
      for (var rowIndex = 0; rowIndex < 4; rowIndex++) {
        row.push({
         squad: null,
         flare: false,
         mortar: false
        });
      }
      this.state.grid.push(row);
    }

    for (let sIndex = 0; sIndex < squad.length; sIndex++) {
      var s = squad[sIndex];
      if (sIndex === (squad.length - 1)) {
        break;
      }
      this.state.grid[s.x][s.y].squad = {
        raw: s.raw,
        tapped: false,
        down: false,
        tx: -1,
        ty: -1
      };
    }
    this.state.tank = [false, false, false, false];

    const deadSquad = squad[squad.length - 1];
    this.luckyLog(`Killing: ${this.luckyName(deadSquad.raw)}`, '#fcc');
    const deadAdj = this.luckyAdjacents(deadSquad.x, deadSquad.y);
    for (var adj of Array.from(deadAdj)) {
      if (this.state.grid[adj.x][adj.y].squad != null) {
        this.state.grid[adj.x][adj.y].squad.down = true;
        this.luckyLog(`...knocking down ${this.luckyName(this.state.grid[adj.x][adj.y].squad.raw)}`, '#fff');
      }
    }

    this.state.bads = [
      { raw: cardutils.MACHINEGUN, col:  1 },
      { raw: cardutils.MACHINEGUN, col:  2 },
      { raw: cardutils.MACHINEGUN, col:  3 },
      { raw: cardutils.MACHINEGUN, col:  4 },

      { raw: cardutils.FLARE,      col:  1 },
      { raw: cardutils.FLARE,      col:  2 },
      { raw: cardutils.FLARE,      col:  3 },
      { raw: cardutils.FLARE,      col:  4 },

      { raw: cardutils.MORTAR,     col:  0 },
      { raw: cardutils.MORTAR,     col:  1 },
      { raw: cardutils.MORTAR,     col:  2 },
      { raw: cardutils.MORTAR,     col:  3 },
      { raw: cardutils.MORTAR,     col:  4 },
      { raw: cardutils.MORTAR,     col:  5 },

      { raw: cardutils.TANK,       col: -1 },
      { raw: cardutils.TANK,       col: -1 },

      { raw: cardutils.INFANTRY1,  col:  0 },
      { raw: cardutils.INFANTRY1,  col:  0 },
      { raw: cardutils.INFANTRY1,  col:  1 },
      { raw: cardutils.INFANTRY1,  col:  2 },
      { raw: cardutils.INFANTRY1,  col:  3 },
      { raw: cardutils.INFANTRY1,  col:  4 },
      { raw: cardutils.INFANTRY1,  col:  5 },
      { raw: cardutils.INFANTRY1,  col:  5 },

      { raw: cardutils.INFANTRY2,  col:  0 },
      { raw: cardutils.INFANTRY2,  col:  2 },
      { raw: cardutils.INFANTRY2,  col:  3 },
      { raw: cardutils.INFANTRY2,  col:  5 }
    ];
    cardutils.shuffle(this.state.bads);
    return this.luckyDealBads();
  },

  luckyName(raw) {
    switch (raw) {
      case cardutils.ANVIL:
        return "The Anvil";
        break;
      case cardutils.ATHLETE:
        return "The Athlete";
        break;
      case cardutils.HAMMER:
        return "The Hammer";
        break;
      case cardutils.JOKER:
        return "The Joker";
        break;
      case cardutils.LEADER:
        return "The Leader";
        break;
      case cardutils.NATURAL:
        return "The Natural";
        break;
      case cardutils.PACIFIST:
        return "The Pacifist";
        break;
      case cardutils.MOUSE:
        return "The Mouse";
        break;
      case cardutils.MACHINEGUN:
        return "Machine Gun";
        break;
      case cardutils.FLARE:
        return "Flare";
        break;
      case cardutils.MORTAR:
        return "Mortar";
        break;
      case cardutils.TANK:
        return "Tank";
        break;
      case cardutils.INFANTRY1:
        return "Infantry1";
        break;
      case cardutils.INFANTRY2:
        return "Infantry2";
        break;
    }
    return "Unknown";
  },

  luckyAdjacents(x, y) {
    const adj = [];
    if (x > 0) {
      adj.push({ x: x - 1, y });
    }
    if (x < 5) {
      adj.push({ x: x + 1, y });
    }
    if (y > 0) {
      adj.push({ x, y: y - 1 });
    }
    if (y < 3) {
      adj.push({ x, y: y + 1 });
    }
    return adj;
  },

  luckyLog(text, color){
    if (color == null) { color = '#fff'; }
    this.state.log.push({
      text,
      color
    });
    return (() => {
      const result = [];
      while (this.state.log.length > cardutils.MAXLOG) {
        result.push(this.state.log.shift());
      }
      return result;
    })();
  },

  luckyUntapSquad() {
    return [0, 1, 2, 3, 4, 5].map((colIndex) =>
      (() => {
        const result = [];
        for (let rowIndex = 0; rowIndex < 4; rowIndex++) {
          this.state.grid[colIndex][rowIndex].flare = false;
          if (this.state.grid[colIndex][rowIndex].squad != null) {
            this.state.grid[colIndex][rowIndex].squad.tapped = false;
            this.state.grid[colIndex][rowIndex].squad.tx = -1;
            result.push(this.state.grid[colIndex][rowIndex].squad.ty = -1);
          } else {
            result.push(undefined);
          }
        }
        return result;
      })());
  },

  luckyAdjustBadCol(col, row) {
    let checkCol;
    console.log(`luckyAdjustBadCol(${col}, ${row})`);
    if ((this.state.grid[col][row].squad == null) && (this.state.grid[col][row].bad == null)) {
      console.log(` * check ${col}, ${row} -> nothing was there`);
      return col;
    }

    let innerSign = 1;
    if (col > 2) {
      innerSign = -1;
    }
    for (let dist = 0; dist < 6; dist++) {
      for (var inner of [true, false]) {
        var d = dist * innerSign;
        if (!inner) {
          d *= -1;
        }
        checkCol = col + d;
        if ((checkCol < 0) || (checkCol > 5)) {
          continue;
        }
        console.log(` * check ${checkCol}, ${row}`);
        if ((this.state.grid[checkCol][row].squad == null) && (this.state.grid[checkCol][row].bad == null)) {
          console.log(` * check ${checkCol}, ${row} -> closest`);
          return checkCol;
        }
      }
    }

    console.log(` * check ${checkCol}, ${row} -> full row, throw it out`);
    return -1;
  },

  luckyDealBads() {
    if (this.state.bads.length < 4) {
      return this.state.lastRound = true;
    } else {
      return (() => {
        const result = [];
        for (let row = 0; row < 4; row++) {
          var bad = this.state.bads.shift();

          if (bad.raw === cardutils.MORTAR) {
            var mortarList = [];
            if (this.state.grid[bad.col][row].squad != null) {
              this.state.grid[bad.col][row].squad.down = true;
              this.state.grid[bad.col][row].squad.tapped = true;
              mortarList.push(this.luckyName(this.state.grid[bad.col][row].squad.raw));
            }
            var adjs = this.luckyAdjacents(bad.col, row);
            for (var adj of Array.from(adjs)) {
              if (this.state.grid[adj.x][adj.y].squad != null) {
                this.state.grid[adj.x][adj.y].squad.down = true;
                mortarList.push(this.luckyName(this.state.grid[adj.x][adj.y].squad.raw));
              }
            }
            this.addTweens([
              this.luckyTween("Encounter", {
                d: 500,
                raw: cardutils.MORTAR,
                sx: bad.col,
                sy: row,
                dx: bad.col,
                dy: row,
                sr: 0,
                dr: 359
              })
            ]);
            if (mortarList.length === 0) {
              result.push(this.luckyLog(`Encounter(${row+1}) Mortar hits: nobody`, '#ffc'));
            } else {
              result.push(this.luckyLog(`Encounter(${row+1}) Mortar hits: ${mortarList.join(', ')}`, '#ffc'));
            }
          } else if (bad.raw === cardutils.FLARE) {
            this.luckyLog(`Encounter(${row+1}) Flare!`, '#ffc');
            this.state.grid[bad.col][row].flare = true;
            result.push(this.addTweens([
              this.luckyTween("Encounter", {
                d: 500,
                raw: cardutils.FLARE,
                sx: bad.col,
                sy: row,
                dx: bad.col,
                dy: row,
                sr: 0,
                dr: 359
              })
            ]));
          } else if (bad.raw === cardutils.TANK) {
            this.luckyLog(`Encounter(${row+1}) Tank!`, '#ffc');
            result.push(this.state.tank[row] = true);
          } else { // anything else
            var col = this.luckyAdjustBadCol(bad.col, row);
            if (col !== -1) {
              this.luckyLog(`Encounter(${row+1}) ${this.luckyName(bad.raw)} (column ${col+1})`, '#ffc');
              this.addTweens([
                this.luckyTween("Encounter", {
                  d: 500,
                  raw: bad.raw,
                  sx: -2,
                  sy: -2,
                  dx: col,
                  dy: row,
                  sr: 270,
                  dr: 359
                })
              ]);
              result.push(this.state.grid[col][row].bad = bad.raw);
            } else {
              result.push(undefined);
            }
          }
        }
        return result;
      })();
    }
  },


  luckyHP(bad) {
    switch (bad) {
      case cardutils.MACHINEGUN:
        return 3;
        break;
      case cardutils.INFANTRY2:
        return 2;
        break;
    }
    return 1;
  },

  luckyCloneGrid() {
    return JSON.parse(JSON.stringify(this.state.grid));
  },

  luckyTween(fakePhase, data) {
    const t = {
      phase: fakePhase,
      grid: JSON.parse(JSON.stringify(this.state.grid))
    };
    for (var k in data) {
      var v = data[k];
      t[k] = v;
    }
    return t;
  },

  luckyHurtBads() {
    const targets = {};
    return [0, 1, 2, 3, 4, 5].map((colIndex) =>
      (() => {
        const result = [];
        for (let rowIndex = 0; rowIndex < 4; rowIndex++) {
          var sq = this.state.grid[colIndex][rowIndex].squad;
          var sqDamage = 1;
          if ((sq != null) && (sq.tx !== -1) && (sq.ty !== -1)) {
            var {
              bad
            } = this.state.grid[sq.tx][sq.ty];
            if (bad != null) {
              var targetTag = `t-${sq.tx}-${sq.ty}`;
              if ((targets[targetTag] == null)) {
                targets[targetTag] = {
                  x: sq.tx,
                  y: sq.ty,
                  hp: this.luckyHP(bad)
                };
              }

              console.log(`[${colIndex}, ${rowIndex}] attacking ${targetTag}: `, targets[targetTag]);
              if ((targets[targetTag].hp > 0) && (targets[targetTag].hp <= sqDamage)) {
                this.luckyLog(`Killed: ${this.luckyName(this.state.grid[sq.tx][sq.ty].bad)}`, '#cfc');
                this.state.grid[sq.tx][sq.ty].bad = null;
                this.addTweens([
                  this.luckyTween("Attacking!", {
                    d: 500,
                    raw: bad,
                    sx: sq.tx,
                    sy: sq.ty,
                    dx: sq.tx,
                    dy: sq.ty,
                    sr: 0,
                    dr: 359
                  })
                ]);
              }
              result.push(targets[targetTag].hp -= sqDamage);
            } else {
              result.push(undefined);
            }
          } else {
            result.push(undefined);
          }
        }
        return result;
      })());
  },

  luckyCounts() {
    const counts = {
      squad: 0,
      bads: 0
    };
    for (let colIndex = 0; colIndex < 6; colIndex++) {
      for (var rowIndex = 0; rowIndex < 4; rowIndex++) {
        var sq = this.state.grid[colIndex][rowIndex].squad;
        if (sq != null) {
          counts.squad += 1;
        }
        var {
          bad
        } = this.state.grid[colIndex][rowIndex];
        if (bad != null) {
          counts.bads += 1;
        }
      }
    }
    return counts;
  },

  luckyHurtSquad() {
    return [0, 1, 2, 3, 4, 5].map((colIndex) =>
      (() => {
        const result = [];
        for (var rowIndex = 0; rowIndex < 4; rowIndex++) {
          var sq = this.state.grid[colIndex][rowIndex].squad;
          if (sq != null) {
            var adjs = this.luckyAdjacents(colIndex, rowIndex);
            result.push((() => {
              const result1 = [];
              for (var adj of Array.from(adjs)) {
                if (this.state.grid[adj.x][adj.y].bad != null) {
                  this.luckyLog(`Killed: ${this.luckyName(this.state.grid[colIndex][rowIndex].squad.raw)}`, '#fcc');
                  this.state.grid[colIndex][rowIndex].squad = null;
                  this.addTweens([
                    this.luckyTween("lolesquads", {
                      d: 500,
                      raw: sq.raw,
                      sx: colIndex,
                      sy: rowIndex,
                      dx: colIndex,
                      dy: rowIndex,
                      sr: 0,
                      dr: 359
                    })
                  ]);
                  break;
                } else {
                  result1.push(undefined);
                }
              }
              return result1;
            })());
          } else {
            result.push(undefined);
          }
        }
        return result;
      })());
  },

  phase() {
    let counts;
    console.log("lucky seven phase!", this.state);
    if ((this.state.phase === WON) || (this.state.phase === LOST)) {
      return;
    }

    let alreadyLost = false;
    if (this.state.phase === MANEUVER) {
      this.luckyUntapSquad();
      this.state.phase = ATTACK;
    } else if (this.state.phase === ATTACK) {
      this.luckyLog("---", '#666');

      // deal damage to mobs, add tweens showing it
      this.luckyHurtBads();
      this.luckyHurtSquad();

      if (this.state.lastRound) {
        // Everything must be dead right here
        counts = this.luckyCounts();
        if (counts.bads > 0) {
          alreadyLost = true;
        }
      }

      if (!alreadyLost) {
        this.luckyUntapSquad();
        this.luckyDealBads();
        this.state.tank = [false, false, false, false];
        this.state.phase = MANEUVER;
      }
    }

    if (alreadyLost) {
      this.luckyLog("You lose! (Ran out of rounds)", '#fcc');
      return this.state.phase = LOST;
    } else {
      counts = this.luckyCounts();
      if (counts.squad === 0) {
        this.luckyLog("You lose! (Everyone is dead)", '#fcc');
        return this.state.phase = LOST;
      } else if ((counts.bads === 0) && (this.state.bads.length === 0)) {
        this.luckyLog("You win!", '#cfc');
        return this.state.phase = WON;
      }
    }
  },

  luckyCanMoveTo(sx, sy, dx, dy) {
    // can't be tapped
    // can't be too far
    // dest can't be enemy
    // dest can't be flare
    // dest can't be tapped squad
    // can't go diagonally between enemies
    return true;
  },

  luckyManeuver(sx, sy, dx, dy) {
    const s = this.state.grid[sx][sy].squad;
    if (s != null) {
      if ((sx === dx) && (sy === dy)) {
        if (!s.tapped) {
          // attempting to stand up / lay down
          s.down = !s.down;
          return s.tapped = true;
        }
      } else if (!s.tapped) {
        // attempting to move
        if (this.luckyCanMoveTo(sx, sy, dx, dy)) {
          const temp = this.state.grid[dx][dy].squad;
          this.state.grid[dx][dy].squad = this.state.grid[sx][sy].squad;
          this.state.grid[sx][sy].squad = temp;
          s.tapped = true;
          if (temp != null) {
            return temp.tapped = true;
          }
        }
      }
    }
  },

  luckyCanAttack(sx, sy, dx, dy) {
    // must target something hittable
    return true;
  },

  luckyAttack(sx, sy, dx, dy) {
    const s = this.state.grid[sx][sy].squad;
    console.log("luckyAttack", s);
    if ((s != null) && !s.tapped && (!s.down || (s.raw === cardutils.MOUSE)) && this.luckyCanAttack(sx, sy, dx, dy)) {
      s.tx = dx;
      s.ty = dy;
      s.tapped = true;
      return console.log(s);
    }
  },

  luckyAct(sx, sy, dx, dy) {
    console.log(`luckyAct (${sx}, ${sy}) -> (${dx}, ${dy})`);

    if (this.state.phase === MANEUVER) {
      return this.luckyManeuver(sx, sy, dx, dy);
    } else if (this.state.phase === ATTACK) {
      return this.luckyAttack(sx, sy, dx, dy);
    }
  },

//    @addTweens [
//      {
//        d: 1000
//        raw: cardutils.GRID
//        sx: dx
//        sy: dy
//        dx: dx
//        dy: dy
//      }
//      {
//        d: 1000
//        raw: cardutils.INFANTRY1
//        sx: -2
//        sy: -2
//        dx: dx
//        dy: dy
//        sr: 0
//        dr: 359
//        so: 0
//        do: 1
//      }
//    ]

  click(type, outerIndex, innerIndex, isRightClick, isMouseUp) {
    if ((this.state.selection.type === 'none') && (type === 'grid')) {
      if ((this.state.grid[outerIndex][innerIndex].squad != null) && !this.state.grid[outerIndex][innerIndex].squad.tapped) {
        return this.select(type, outerIndex, innerIndex);
      }
    } else {
      if (type === 'grid') {
        this.luckyAct(this.state.selection.outerIndex, this.state.selection.innerIndex, outerIndex, innerIndex);
      }
      this.select('none');

      return console.log(this.state.grid);
    }
  },

  won() {
    return (this.state.phase === WON);
  },

  lost() {
    return (this.state.phase === LOST);
  }
};

export default mode;
