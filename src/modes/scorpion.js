/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS202: Simplify dynamic range loops
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
import * as cardutils from '../cardutils';

const mode = {
  name: "Scorpion",
  help: `\
| GOAL:

Arrange four sets of cards in suit, from, king down to ace.

| PLAY:

Build columns down and in suit. Any face up card may be moved, along
with all other cards on top of it, to a completely exposed card which
meets the build requirements. Flip face down cards which become exposed
face up.

When play comes to a standstill (or sooner if desired), deal the three
remaining cards of the stock to the first three columns, then continue if
possible. Empty spaces in columns may be filled with any cards.

There is no redeal.

| HARD MODE:

Easy - 2 cards face down in the first 4 columns. Fill empties with any cards.

Hard - 3 cards face down in the first 4 columns. Fill empties with Kings only.\
`,

  newGame() {
    let faceDownCount, faceUpCount;
    this.state = {
      hard: this.hard,
      draw: {
        pos: 'bottom',
        cards: []
      },
      selection: {
        type: 'none',
        outerIndex: 0,
        innerIndex: 0
      },
      pile: {
        show: 1,
        cards: []
      },
      foundations: [],
      work: []
    };

    const deck = cardutils.shuffle(__range__(0, 52, false));
    if (this.hard) {
      faceDownCount = 3;
      faceUpCount = 4;
    } else {
      faceDownCount = 2;
      faceUpCount = 5;
    }
    for (let columnIndex = 0; columnIndex < 7; columnIndex++) {
      var i;
      var col = [];
      if (columnIndex < 4) {
        var asc, end;
        var asc1, end1;
        for (i = 0, end = faceDownCount, asc = 0 <= end; asc ? i < end : i > end; asc ? i++ : i--) {
          col.push(deck.shift() | cardutils.FLIP_FLAG);
        }
        for (i = 0, end1 = faceUpCount, asc1 = 0 <= end1; asc1 ? i < end1 : i > end1; asc1 ? i++ : i--) {
          col.push(deck.shift());
        }
      } else {
        for (i = 0; i < 7; i++) {
          col.push(deck.shift());
        }
      }
      this.state.work.push(col);
    }

    return this.state.draw.cards = deck;
  },

  scorpionDeal() {
    for (let workIndex = 0; workIndex < this.state.work.length; workIndex++) {
      var work = this.state.work[workIndex];
      if (this.state.draw.cards.length === 0) {
        break;
      }
      work.push(this.state.draw.cards.pop());
    }

    return this.select('none');
  },

  click(type, outerIndex, innerIndex, isRightClick, isMouseUp) {
    if (isRightClick) {
    //   @scorpionDeal()
      return;
    }

    switch (type) {
      // -------------------------------------------------------------------------------------------
      case 'draw':
        return this.scorpionDeal();

      // -------------------------------------------------------------------------------------------
      case 'work':
        // Potential selections or destinations
        var src = this.getSelection();

        var sameWorkPile = (this.state.selection.type === 'work') && (this.state.selection.outerIndex === outerIndex);
        if ((src.length > 0) && !sameWorkPile) {
          // Moving into work
          const dst = this.state.work[outerIndex];

          let validFlags = cardutils.VALIDMOVE_DESCENDING | cardutils.VALIDMOVE_MATCHING_SUIT;
          if (this.state.hard) {
            validFlags |= cardutils.VALIDMOVE_EMPTY_KINGS_ONLY;
          }
          if (cardutils.validMove(src, dst, validFlags)) {
            for (var c of Array.from(src)) {
              dst.push(c);
            }
            this.eatSelection();
          }

          return this.select('none');
        } else if (sameWorkPile && isMouseUp) {
          return this.select('none');
        } else {
          // Selecting a fresh column
          const col = this.state.work[outerIndex];
          while ((innerIndex < col.length) && (col[innerIndex] & cardutils.FLIP_FLAG)) {
            // Don't select face down cards
            innerIndex += 1;
          }

          return this.select(type, outerIndex, innerIndex);
        }


      // -------------------------------------------------------------------------------------------
      default:
        // Probably a background click, just forget the selection
        return this.select('none');
    }
  },

  won() {
    if (this.state.draw.cards.length > 0) {
      return false;
    }

    // each work must either be empty or have a perfect 13 card run of same-suit in it
    for (let workIndex = 0; workIndex < this.state.work.length; workIndex++) {
      var work = this.state.work[workIndex];
      if (work.length === 0) {
        continue;
      }
      if (work.length !== 13) {
        // console.log "column #{workIndex} isnt 13 cards"
        return false;
      }
      for (var cIndex = 0; cIndex < work.length; cIndex++) {
        var c = work[cIndex];
        var info = cardutils.info(c);
        if (info.flip) {
          return false;
        }
        if (info.value !== (12 - cIndex)) {
          // console.log "column #{workIndex} card #{cIndex} breaks the pattern"
          return false;
        }
      }
    }
    return true;
  }
};

export default mode;

function __range__(left, right, inclusive) {
  let range = [];
  let ascending = left < right;
  let end = !inclusive ? right : ascending ? right + 1 : right - 1;
  for (let i = left; ascending ? i < end : i > end; ascending ? i++ : i--) {
    range.push(i);
  }
  return range;
}