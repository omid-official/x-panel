package controller

import (
	"encoding/json"
	"fmt"
	"strconv"
	"x-panel/database/model"
	"x-panel/logger"
	"x-panel/web/global"
	"x-panel/web/service"
	"x-panel/web/session"

	"github.com/gin-gonic/gin"
)

type InboundController struct {
	inboundService service.InboundService
	xrayService    service.XrayService
}

func NewInboundController(g *gin.RouterGroup) *InboundController {
	a := &InboundController{}
	a.initRouter(g)
	a.startTask()
	return a
}

func (a *InboundController) initRouter(g *gin.RouterGroup) {
	g = g.Group("/inbound")

	g.POST("/list", a.getInbounds)
	g.POST("/add", a.addInbound)
	g.POST("/del/:id", a.delInbound)
	g.POST("/update/:id", a.updateInbound)
}

func (a *InboundController) startTask() {
	webServer := global.GetWebServer()
	c := webServer.GetCron()
	c.AddFunc("@every 10s", func() {
		if a.xrayService.IsNeedRestartAndSetFalse() {
			err := a.xrayService.RestartXray(false)
			if err != nil {
				logger.Error("restart xray failed:", err)
			}
		}
	})
}

func (a *InboundController) getInbounds(c *gin.Context) {
	user := session.GetLoginUser(c)
	inbounds, err := a.inboundService.GetInbounds(user.Id)
	if err != nil {
		jsonMsg(c, "Obtain", err)
		return
	}
	jsonObj(c, inbounds, nil)
}

func (a *InboundController) addInbound(c *gin.Context) {
	inbound := &model.Inbound{}
	err := c.ShouldBind(inbound)
	if err != nil {
		jsonMsg(c, "Add to", err)
		return
	}
	var data map[string]interface{}
	err = json.Unmarshal([]byte(inbound.Settings), &data)
	if err != nil {
		jsonMsg(c, "Something went wrong", err)
		return
	}
	user := session.GetLoginUser(c)
	inbound.UserId = user.Id
	inbound.Enable = true
	inbound.Tag = fmt.Sprintf("inbound-%v", inbound.Port)
	inbound.Email = fmt.Sprintf("%v@gmail.com", inbound.Port)
	clients := data["clients"].([]interface{})
	client := clients[0].(map[string]interface{})
	client["email"] = inbound.Email
	modifiedSetting, err := json.Marshal(data)
	if err != nil {
		jsonMsg(c, "Something went wrong", err)
		return
	}
	inbound.Settings = string(modifiedSetting)
	err = a.inboundService.AddInbound(inbound)
	jsonMsg(c, "Add to", err)
	if err == nil {
		a.xrayService.SetToNeedRestart()
	}
}

func (a *InboundController) delInbound(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		jsonMsg(c, "delete", err)
		return
	}
	err = a.inboundService.DelInbound(id)
	jsonMsg(c, "delete", err)
	if err == nil {
		a.xrayService.SetToNeedRestart()
	}
}

func (a *InboundController) updateInbound(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		jsonMsg(c, "Revise", err)
		return
	}
	inbound := &model.Inbound{
		Id: id,
	}
	err = c.ShouldBind(inbound)
	if err != nil {
		jsonMsg(c, "Revise", err)
		return
	}
	err = a.inboundService.UpdateInbound(inbound)
	jsonMsg(c, "Revise", err)
	if err == nil {
		a.xrayService.SetToNeedRestart()
	}
}
