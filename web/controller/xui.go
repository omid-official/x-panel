package controller

import (
	"github.com/gin-gonic/gin"
)

type XPANELController struct {
	BaseController

	inboundController *InboundController
	settingController *SettingController
}

func NewXPANELController(g *gin.RouterGroup) *XPANELController {
	a := &XPANELController{}
	a.initRouter(g)
	return a
}

func (a *XPANELController) initRouter(g *gin.RouterGroup) {
	g = g.Group("/xpanel")
	g.Use(a.checkLogin)

	g.GET("/", a.index)
	g.GET("/inbounds", a.inbounds)
	g.GET("/setting", a.setting)

	a.inboundController = NewInboundController(g)
	a.settingController = NewSettingController(g)
}

func (a *XPANELController) index(c *gin.Context) {
	html(c, "index.html", "system status", nil)
}

func (a *XPANELController) inbounds(c *gin.Context) {
	html(c, "inbounds.html", "inbound list", nil)
}

func (a *XPANELController) setting(c *gin.Context) {
	html(c, "setting.html", "set up", nil)
}
