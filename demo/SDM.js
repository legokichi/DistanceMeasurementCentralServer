window.Point = (function () {
    function Point(x, y) {
        this.x = x;
        this.y = y;
    }
    Point.prototype.plus = function (pt) {
        return new Point(this.x + pt.x, this.y + pt.y);
    };
    Point.prototype.minus = function (pt) {
        return new Point(this.x - pt.x, this.y - pt.y);
    };
    Point.prototype.times = function (num) {
        return new Point(num * this.x, num * this.y);
    };
    Point.prototype.distance = function (pt) {
        return Math.sqrt(Math.pow(pt.x - this.x, 2) +
            Math.pow(pt.y - this.y, 2));
    };
    return Point;
})();
window.SDM = (function () {
    function SDM(pts, ds, a) {
        if (a === void 0) { a = 0.05; }
        this.points = pts;
        this.distance = ds;
        this.a = a;
    }
    SDM.prototype.step = function () {
        var _this = this;
        var _pts = [];
        for (var i = 0; i < this.points.length; i++) {
            var delta = this.distance[i].reduce((function (sumPt, _, j) {
                if (i === j) {
                    return sumPt;
                }
                else {
                    return sumPt.plus((_this.points[i].minus(_this.points[j])).times((1 - _this.distance[i][j] / _this.points[i].distance(_this.points[j]))));
                }
            }), new Point(0, 0)).times(2);
            _pts[i] = this.points[i].minus(delta.times(this.a));
        }
        this.points = _pts;
    };
    SDM.prototype.det = function () {
        var _this = this;
        return this.points.reduce((function (sum, _, i) {
            return sum + _this.points.reduce((function (sum, _, j) {
                return i === j ? sum :
                    sum + Math.pow(_this.points[i].distance(_this.points[j]) - _this.distance[i][j], 2);
            }), 0);
        }), 0);
    };
    return SDM;
})();
