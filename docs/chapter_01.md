Chapter1 Terraform入門
---
[READMEに戻る](../README.md)


# ■ 0. Terraform入門

このチュートリアルではTerraform自体をどう利用するのかは説明しません。  
Terraform自体の説明は下記を参考にしてみてください。

- [それ、どこに出しても恥ずかしくない Terraformコードになってるか？ | AWS](https://esa-storage-tokyo.s3-ap-northeast-1.amazonaws.com/uploads/production/attachments/5809/2023/07/07/19598/c89126e6-8d48-4e34-a654-6fd29b63756e.pdf)
- 公式ドキュメント
  - [Providers](https://developer.hashicorp.com/terraform/language/providers)  
  - [Resources](https://developer.hashicorp.com/terraform/language/resources)  
    インフラオブジェクトを記述するためのブロック。
    - [Meta-Arguments](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on)  
    depends_on, count, for_each, lifecycleなどどのリソースでも共通で利用できるパラメータに関する説明
  - [Data Sources](https://developer.hashicorp.com/terraform/language/data-sources)  
  - [Variable and Outputs](https://developer.hashicorp.com/terraform/language/values)  
  variable, output, locals など変数定義や出力で利用するブロック
  - [Modules](https://developer.hashicorp.com/terraform/language/modules)  
  複数リソースをまとめるための仕組み
  - [Functions](https://developer.hashicorp.com/terraform/language/functions)  
  Terraform内で利用できる組み込み関数




# ■ 1. ディレクトリ作成

terraformリソースは `terraform/` ディレクトリ配下に定義します。

## ディレクトリ構成

- `terraform/`
  - `envs/`
    dev, stg, prd など、環境毎にディレクトリを切る
  - `modules/`
    サービス毎・ライフサイクル毎にある程度リソースをグループ化したモジュールを配置

```bash
# 半角英数字のみ
ENV_NAME="xxxxx"

mkdir -p "terraform/envs/${ENV_NAME}" "terraform/modules"
```

# ■ 2. 



# ■ terraformデプロイ

```bash
cd terraform-sample/envs/dev
terraform init
terraform plan
terraform apply -auto-approve
```

# ■ リソースの削除

```bash
cd terraform-sample/envs/dev

# すべて削除
terraform destroy

# アプリリソースのみ削除
terraform destroy -target=module.app
```