//
//  SocketIOClientManager.swift
//  Assassin
//
//  Created by Yuanhao Li on 22/11/15.
//  Copyright © 2015 Yuanhao Li. All rights reserved.
//


protocol SocketManagerDelegate {
    func message(socket: SocketIOClient, onConnect data: AnyObject, ack: SocketAckEmitter?)
    func message(socket: SocketIOClient, onDamage data: AnyObject, ack: SocketAckEmitter?)
}


class SocketManager {
    var socket: SocketIOClient
    var delegate: SocketManagerDelegate
    
    init(socket: SocketIOClient, delegate: SocketManagerDelegate) {
        self.socket = socket
        self.delegate = delegate
        self.initSocket()
    }
    
    func initSocket() {
        self.socket.on("connect", callback:  { data, ack in
            self.delegate.message(self.socket, onConnect: data, ack: ack)
        })
        
        self.socket.on("damage", callback: { data, ack in
            if let data: AnyObject = data[0] {
                self.delegate.message(self.socket, onDamage: data, ack: ack)
            }
        })
        
        self.socket.connect()
    }
    
}
