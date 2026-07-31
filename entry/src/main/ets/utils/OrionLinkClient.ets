import { socket } from '@kit.NetworkKit';

const ORIONLINK_MAGIC = 'ORIONLINK|';

export class OrionLinkClient {
  private udp: socket.UDPSocket | null = null;
  private targetAddress: socket.NetAddress = { address: '0.0.0.0', port: 0, family: 1 };

  async connect(ip: string, port: number): Promise<boolean> {
    try {
      this.udp = socket.constructUDPSocketInstance();
      this.targetAddress = { address: ip, port: port, family: 1 };
      await this.udp.bind({ address: '0.0.0.0', port: 0, family: 1 });
      return true;
    } catch (e) {
      this.udp = null;
      return false;
    }
  }

  async sendMove(dx: number, dy: number): Promise<boolean> {
    let json = `{"t":"move","dx":${dx},"dy":${dy}}`;
    return this.send(json);
  }

  async sendClick(button: string): Promise<boolean> {
    let json = `{"t":"click","button":"${button}"}`;
    return this.send(json);
  }

  async sendScroll(dx: number, dy: number): Promise<boolean> {
    let json = `{"t":"scroll","dx":${dx},"dy":${dy}}`;
    return this.send(json);
  }

  private async send(json: string): Promise<boolean> {
    if (!this.udp) {
      return false;
    }
    let data = ORIONLINK_MAGIC + json;
    let options: socket.UDPSendOptions = {
      data: data,
      address: this.targetAddress
    };
    try {
      await this.udp.send(options);
      return true;
    } catch (e) {
      return false;
    }
  }

  async close(): Promise<void> {
    if (this.udp) {
      try {
        await this.udp.close();
      } catch (e) {
      }
      this.udp = null;
    }
  }
}
