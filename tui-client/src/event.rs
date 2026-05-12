use std::time::Duration;

use crossterm::event::{Event as CtEvent, EventStream, KeyEvent, KeyEventKind};
use futures::StreamExt;
use tokio::sync::mpsc;

use crate::app::Msg;

pub fn spawn_input_loop(tx: mpsc::UnboundedSender<Msg>) {
    tokio::spawn(async move {
        let mut stream = EventStream::new();
        loop {
            match stream.next().await {
                Some(Ok(CtEvent::Key(KeyEvent { kind, .. })))
                    if kind != KeyEventKind::Press =>
                {
                    continue;
                }
                Some(Ok(CtEvent::Key(key))) => {
                    if tx.send(Msg::Key(key)).is_err() {
                        break;
                    }
                }
                Some(Ok(CtEvent::Resize(w, h))) => {
                    if tx.send(Msg::Resize(w, h)).is_err() {
                        break;
                    }
                }
                Some(Ok(_)) => {}
                Some(Err(_)) => break,
                None => break,
            }
        }
    });
}

pub fn spawn_tick_loop(tx: mpsc::UnboundedSender<Msg>, period: Duration) {
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(period);
        loop {
            interval.tick().await;
            if tx.send(Msg::Tick).is_err() {
                break;
            }
        }
    });
}
